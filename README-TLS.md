### LETSENCRYPT CERTS

Using certbot/route53 image to generate the TLS certs:

```
docker run -it --rm --name certbot \
    --env-file env-file  \
    -v "/home/chee/.aws:/root/.aws" \
    -v "${PWD}/tls:/etc/letsencrypt" \
    -v "${PWD}/tls:/var/lib/letsencrypt" \
    certbot/dns-route53 certonly \
    -d 'teka-teka.xyz' \
    -d 'vault.teka-teka.xyz' \
    -m merchantdoom@gmail.com \
    --agree-tos --server https://acme-v02.api.letsencrypt.org/directory
```

To renew:
```
docker run -it --rm --name certbot \
    --env-file env-file  \
    -v "/home/chee/.aws:/root/.aws" \
    -v "${PWD}/tls:/etc/letsencrypt" \
    -v "${PWD}/tls:/var/lib/letsencrypt" \
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