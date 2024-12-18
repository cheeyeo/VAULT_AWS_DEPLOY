package main

import (
	"context"
	"fmt"
	"log"
	"os"
	"sync"
	"time"

	"github.com/aws/aws-sdk-go-v2/aws"
	"github.com/aws/aws-sdk-go-v2/config"
	"github.com/aws/aws-sdk-go-v2/service/autoscaling"
	"github.com/aws/aws-sdk-go-v2/service/ec2"
	ec2_types "github.com/aws/aws-sdk-go-v2/service/ec2/types"
	"github.com/aws/aws-sdk-go-v2/service/ssm"
	"github.com/aws/aws-sdk-go-v2/service/ssm/types"
)

func main() {
	var mainInstance string

	cfg, err := config.LoadDefaultConfig(context.TODO())
	if err != nil {
		log.Fatal(err)
	}

	client1 := autoscaling.NewFromConfig(cfg)
	param := &autoscaling.DescribeAutoScalingGroupsInput{
		AutoScalingGroupNames: []string{
			os.Getenv("ASG"),
		},
	}

	customRetryable := func(ctx context.Context, params *autoscaling.DescribeAutoScalingGroupsInput, output *autoscaling.DescribeAutoScalingGroupsOutput, err error) (bool, error) {
		if len(output.AutoScalingGroups[0].Instances) < 1 {
			return true, nil
		}

		return false, nil
	}

	waiter := autoscaling.NewGroupInServiceWaiter(client1, func(o *autoscaling.GroupInServiceWaiterOptions) {
		o.Retryable = customRetryable
	})
	waiter.Wait(context.TODO(), param, time.Duration(300*float64(time.Second)))

	resp, err := client1.DescribeAutoScalingGroups(context.TODO(), param)
	if err != nil {
		log.Fatal(err)
	}
	fmt.Printf("RESP: %+v\n", resp)

	var instances []string
	for _, r := range resp.AutoScalingGroups[0].Instances {
		instances = append(instances, *r.InstanceId)
	}
	fmt.Println(instances)

	ctx, cancelFunc := context.WithCancel(context.Background())
	defer cancelFunc()

	ch := make(chan string)

	ec2_client := ec2.NewFromConfig(cfg)

	var wg sync.WaitGroup
	wg.Add(len(instances))

	for _, inner_instance := range instances {
		go func(instance string) {
			defer wg.Done()

			waiter := ec2.NewInstanceStatusOkWaiter(ec2_client)
			param := &ec2.DescribeInstanceStatusInput{
				InstanceIds: []string{
					instance,
				},
			}

			// err := waiter.Wait(context.TODO(), param, time.Duration(300*float64(time.Second)))
			err := waiter.Wait(ctx, param, time.Duration(300*float64(time.Second)))

			if err != nil {
				fmt.Println("Error In go-routine ", err)
				cancelFunc()
				return
			}

			select {
			case ch <- instance:
				// Exits waiter loop for first instance which is ready
				fmt.Println("In go routine: ", instance)
				cancelFunc()
			case <-ctx.Done():
			}

		}(inner_instance)
	}

loop:
	for {
		select {
		case s := <-ch:
			mainInstance = s
			fmt.Println("In main: ", mainInstance)
		case <-ctx.Done():
			fmt.Println("Cancelled")
			break loop
		}
	}
	wg.Wait()

	fmt.Println("AFTER WAITGROUP... ")
	fmt.Println("RUNNING SSM COMMAND ON: ", mainInstance)

	// Add tag to main instance to mark it as leader
	params := &ec2.CreateTagsInput{
		Resources: []string{mainInstance},
		Tags: []ec2_types.Tag{
			{
				Key:   aws.String("ROLE"),
				Value: aws.String("LEADER"),
			},
		},
	}
	_, err = ec2_client.CreateTags(context.TODO(), params)
	if err != nil {
		log.Fatal(err)
	}

	ssm_client := ssm.NewFromConfig(cfg)
	param2 := &ssm.SendCommandInput{
		DocumentName:    aws.String(os.Getenv("DOC")),
		DocumentVersion: aws.String("$LATEST"),
		InstanceIds:     []string{mainInstance},
		CloudWatchOutputConfig: &types.CloudWatchOutputConfig{
			CloudWatchLogGroupName:  aws.String(os.Getenv("CLOUDWATCH_LOG")),
			CloudWatchOutputEnabled: true,
		},
		MaxConcurrency: aws.String("50"),
		MaxErrors:      aws.String("0"),
		TimeoutSeconds: aws.Int32(600),
	}
	resp2, err := ssm_client.SendCommand(
		context.TODO(),
		param2,
	)
	if err != nil {
		log.Fatal(err)
	}

	fmt.Println(resp2.Command.Status)
}
