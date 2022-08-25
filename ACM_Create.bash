#!/bin/bash

# Colors used in script
gray="\\e[37m"
blue="\\e[36m"
red="\\e[31m"
green="\\e[32m"
orange="\\e[33m"
reset="\\e[0m"

# Functions to call loggings
info()    { printf "${blue}INFO: $*${reset}\n" 1>&2; }
warning() { printf "${orange}WARN: $*${reset}\n" 1>&2; }
error()   { printf "${red}ERROR: $*${reset}\n" 1>&2; }
success() { printf "${green}✔ $*${reset}\n" 1>&2; }
fail()    { printf "${red}✖ $*${reset}\n" 1>&2; exit 1; }
debug()   { [[ "${DEBUG}" == "true" ]] && echo -e "${gray}DEBUG: $*${reset}\n"  1>&2 || true; }

# Check arguments
[[ -z ${1} ]] && fail "First account (certificate account) is required" || [[ "${1}" == "ixor."*"-admin" ]] && info "Valid certificate account" || fail "Certificate account has to be like ixor.[account]-admin"
[[ -z ${2} ]] && fail "At least one domain is required, more are allowed (space separated)" || [[ "${2}" == *"."* ]] && info "${2} is a valid domain" || fail "${2} is not a valid domain"

# Create variables from arguments
CERT_ACCOUNT=${1}; shift
MAIN_DOMAIN=${1}; shift
[[ -n ${1} ]] && EXTRA_DOMS="${@} "
# Check if EXTRA_OPTS are valid domains
for DOM in $EXTRA_DOMS; do [[ "${DOM}" == *"."* ]] && info "${DOM} is a valid domain" || fail "${DOM} is not a valid domain"; done
[[ -z ${EXTRA_DOMS} ]] && EXTRA_OPTS="" || EXTRA_OPTS=" --subject-alternative-names ${EXTRA_DOMS}"

# Check if cche of assuming roles exist
source ~/.assumerole.d/cache/ixor.tooling-admin && info "Cache for ixor.tooling-admin exists" || fail "Please issue 'assumerole ixor.tooling-admin' before running this script"
source ~/.assumerole.d/cache/${CERT_ACCOUNT} && info "Cache for ${CERT_ACCOUNT} exists" || fail "Please issue 'assumerole ${CERT_ACCOUNT}' before running this script"

# Create certificate for CERT_ACCOUNT
CERT_ARN_EU_CENTRAL_1=$(aws acm request-certificate --region eu-central-1 --domain-name ${MAIN_DOMAIN} --validation-method DNS ${EXTRA_OPTS} --output=text) && success "Created certificate in \"EU-CENTRAL-1\" region" || fail "Failed to create certificate in \"EU-CENTRAL-1\" region"
CERT_ARN_US_EAST_1=$(aws acm request-certificate --region us-east-1 --domain-name ${MAIN_DOMAIN} --validation-method DNS ${EXTRA_OPTS} --output=text) && success "Created certificate in \"US-EAST-1\" region" || fail "Failed to create certificate in \"US-EAST-1\" region"
sleep 10
CERT_NAMES=$(aws acm describe-certificate --certificate-arn ${CERT_ARN_EU_CENTRAL_1} --query "Certificate.DomainValidationOptions[].ResourceRecord.Name")
CERT_VALUES=$(aws acm describe-certificate --certificate-arn ${CERT_ARN_EU_CENTRAL_1} --query "Certificate.DomainValidationOptions[].ResourceRecord.Value")
# Assuming ixor.tooling-admin role
source ~/.assumerole.d/cache/ixor.tooling-admin
# Scan Route 53 for all hosted zones
HOSTED_ZONES=$(aws route53 list-hosted-zones --query "HostedZones[].Name" --output=text)
DOMAINS="${MAIN_DOMAIN} ${EXTRA_DOMS}"
for DOMAIN in $DOMAINS; do
  [[ "${DOMAIN}" == "*."* ]] && DOMAIN=$(echo "${DOMAIN:2}")

  if [[ "${HOSTED_ZONES}" == *"${DOMAIN}"* ]]; then
   info "Hosted zone for ${DOMAIN} exists"
   # Getting hosted zone id using the domain name
   HOSTED_ZONE_ID=$(aws route53 list-hosted-zones-by-name --dns-name ${DOMAIN} --query "HostedZones[0].Id" --output=text)
   # Extract all DNS Entries using the hosted zone id
   DNS_ENTRIES=$(aws route53 list-resource-record-sets --hosted-zone-id $HOSTED_ZONE_ID --query "ResourceRecordSets[].Name" --output=text)
   LEN=$(echo ${CERT_NAMES} | jq '. | length')
   for (( i=0; i<${LEN}; i++ )); do
     # Getting CERT_NAME $i and CERT_VALUE $i and removing double-quotes
     CERT_NAME=$(echo ${CERT_NAMES} | jq ".[${i}]") && CERT_NAME="${CERT_NAME%\"}" && CERT_NAME="${CERT_NAME#\"}"
     CERT_VALUE=$(echo ${CERT_VALUES} | jq ".[${i}]") CERT_VALUE="${CERT_VALUE%\"}" && CERT_VALUE="${CERT_VALUE#\"}"
     # Checking if the domain name is in the cert name
     if [[ "${CERT_NAME}" == *"${DOMAIN}"* ]]; then
       # Check if the DNS entry already exists
       if [[ "$DNS_ENTRIES" == *"${CERT_NAME}"* ]]; then info "DNS Entry ${CERT_NAME} already exists in hosted zone ${DOMAIN}"; else
         info "Creating DNS Entry for certificate ${CERT_NAME}"
         # Creating .tmp.json file & creating DNS Entry
         CMD=$(echo "{\"Changes\": [{\"Action\": \"CREATE\",\"ResourceRecordSet\": {\"Name\": \"${CERT_NAME}\",\"Type\": \"CNAME\",\"TTL\": 300,\"ResourceRecords\": [{\"Value\": \"${CERT_VALUE}\"}]}}]}" > .tmp.json) &&
         CREATE_DNS_ENTRIES=$(aws route53 change-resource-record-sets --hosted-zone-id ${HOSTED_ZONE_ID} --change-batch file://.tmp.json) && success "Created DNS-Entry ${CERT_NAME}"
         # Removing JSON File
         rm .tmp.json
       fi
      fi
    done
  else
    # When the hosted zone does not exist in ixor.tooling-admin account, it shows this error
    # The program doesn't close because it's possible that the Domain is not managed by Ixor
    error "No hosted zone for ${DOMAIN} in \"ixor.tooling-admin\" account"
  fi
done

