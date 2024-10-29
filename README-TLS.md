### LETSENCRYPT CERTS

Using certbot/route53 image to generate the TLS certs:

```
docker pull certbot/dns-route53:latest
```

```
docker run -it --rm --name certbot \
    --env-file env-file  \
    -v "/home/chee/.aws:/root/.aws" \
    -v "${PWD}/tls2:/etc/letsencrypt" \
    -v "${PWD}/tls2:/var/lib/letsencrypt" \
    certbot/dns-route53 certonly \
    -d 'teka-teka.xyz' \
    -d 'vault.teka-teka.xyz' \
    -m merchantdoom@gmail.com \
    --agree-tos --server https://acme-v02.api.letsencrypt.org/directory
```

Result:
```
Successfully received certificate.
Certificate is saved at: /etc/letsencrypt/live/teka-teka.xyz/fullchain.pem
Key is saved at:         /etc/letsencrypt/live/teka-teka.xyz/privkey.pem
This certificate expires on 2025-01-27.
These files will be updated when the certificate renews.
```


Certificate => fullchain.pem
Private key => privkey.pem

The certbot image runs as root user so the generated certs need to have permissions changed:
```
sudo chown -R chee:chee tls
```

To renew:
```
docker run -it --rm --name certbot \
    --env-file env-file  \
    -v "/home/chee/.aws:/root/.aws" \
    -v "${PWD}/tls2:/etc/letsencrypt" \
    -v "${PWD}/tls2:/var/lib/letsencrypt" \
    certbot/dns-route53 renew \
    --agree-tos --server https://acme-v02.api.letsencrypt.org/directory
```



* Need to ensure DNSSEC is disabled else it will fail with 

```
 looking up TXT for _acme-challenge.teka-teka.xyz: DNSSEC: DNSKEY Missing: validation failure <_acme-challenge.teka-teka.xyz. TXT IN>: No DNSKEY record from 205.251.199.210 for key teka-teka.xyz. while building chain of trust
```

Disable DNSSEC from parent zone i.e. squarespace then disable it in child zone

Use following tool to check for DS records:

- https://dnschecker.org/



References:
- https://certbot-dns-route53.readthedocs.io/en/stable/

- https://hub.docker.com/r/certbot/dns-route53

- https://medium.com/w-logs/generate-standalone-ssl-certificate-with-lets-encrypt-for-aws-route-53-25a30ca3062