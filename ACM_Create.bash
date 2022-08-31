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

# Function to check if cache is valid
checkCache()  {
  # Check if cache of assuming roles exist
  source ~/.assumerole.d/cache/${1} &&
    info "Cache for ${AWS_ACCOUNT} exists" ||
    fail "Please issue 'assumerole ${1}' before running this script"

  aws sts get-caller-identity >/dev/null 2>&1 &&
    success "Cache for ${AWS_ACCOUNT} is valid" ||
    fail "Cache for ${AWS_ACCOUNT} is expired, please issue 'assumerole ${AWS_ACCOUNT}' to renew the cache"
 }

# Check arguments
[[ -z ${1} ]] &&
  fail "First account (certificate account) is required" ||
  [[ "${1}" == *"."* ]] &&
    info "${1} is a valid certificate account" ||
    fail "${1} is not a valid certificate account, it should be 'ixor.*'"

[[ -z ${2} ]] &&
  fail "At least one domain is required, more are allowed (space separated)" ||
  [[ "${2}" == *"."* ]] &&
    info "${2} is a valid domain" ||
    fail "${2} is not a valid domain"

# Create variables from arguments
CERT_ACCOUNT=${1}; shift
MAIN_DOMAIN=${1}; shift
[[ -n ${1} ]] && EXTRA_DOMS="${@} "
# Check if EXTRA_OPTS are valid domains
for DOM in $EXTRA_DOMS; do
  [[ "${DOM}" == *"."* ]] &&
    info "${DOM} is a valid domain" ||
    fail "${DOM} is not a valid domain";
done
[[ -z ${EXTRA_DOMS} ]] &&
  EXTRA_OPTS="" ||
  EXTRA_OPTS=" --subject-alternative-names ${EXTRA_DOMS}"

checkCache "${ASSUMEROLE_TOOLING_ACCOUNT:-ixor.tooling-admin}"

checkCache "${CERT_ACCOUNT}"

# Create certificate for CERT_ACCOUNT
info "Creating Certificates in eu-central-1 and us-east-1"
CERT_ARN_EU_CENTRAL_1=$(aws acm request-certificate --region eu-central-1 --domain-name ${MAIN_DOMAIN} --validation-method DNS ${EXTRA_OPTS} --output=text) &&
  success "Created certificate in \"EU-CENTRAL-1\" region" ||
  fail "Failed to create certificate in \"EU-CENTRAL-1\" region"

CERT_ARN_US_EAST_1=$(aws acm request-certificate --region us-east-1 --domain-name ${MAIN_DOMAIN} --validation-method DNS ${EXTRA_OPTS} --output=text) &&
  success "Created certificate in \"US-EAST-1\" region" ||
    fail "Failed to create certificate in \"US-EAST-1\" region"

info "Waiting for DNS Name and Value to generate"
sleep 10
DNS_NAMES=$(aws acm describe-certificate --certificate-arn ${CERT_ARN_EU_CENTRAL_1} --query "Certificate.DomainValidationOptions[].ResourceRecord.Name")
DNS_VALUES=$(aws acm describe-certificate --certificate-arn ${CERT_ARN_EU_CENTRAL_1} --query "Certificate.DomainValidationOptions[].ResourceRecord.Value")
# Assuming ixor.tooling-admin role
source ~/.assumerole.d/cache/ixor.tooling-admin
# Scan Route 53 for all hosted zones
HOSTED_ZONES=$(aws route53 list-hosted-zones --query "HostedZones[].Name" --output=text)
DOMAINS="${MAIN_DOMAIN} ${EXTRA_DOMS}"
LEN=$(echo ${DNS_NAMES} | jq '. | length ')
for (( i=0; i<${LEN}; i++ )); do
  DNS_NAME=$(echo ${DNS_NAMES} | jq -r ".[${i}]")
  DNS_VALUE=$(echo ${DNS_VALUES} | jq -r ".[${i}]")

  DOMAIN=$(echo "${DNS_NAME}" | awk -F. '{printf("%s.%s", $(NF-2), $(NF-1))}')

  if [[ ${HOSTED_ZONES} == *"${DOMAIN}"* ]]; then
    info "Hosted zone for ${DOMAIN} exists"
    if nslookup ${DNS_NAME} >/dev/null 2>&1; then
      info "DNS Entry already exists for ${DOMAIN}, not creating it again"
    else
      error "No DNS Entry \"${DNS_NAME}\" found"
      info "Creating DNS Entry"
      HOSTED_ZONE_ID=$(aws route53 list-hosted-zones-by-name --dns-name ${DOMAIN} --query "HostedZones[0].Id" --output=text)
      #Creating .tmp.json file & creating DNS Entry
      echo "{\"Changes\": [{\"Action\": \"CREATE\",\"ResourceRecordSet\": {\"Name\": \"${DNS_NAME}\",\"Type\": \"CNAME\",\"TTL\": 300,\"ResourceRecords\": [{\"Value\": \"${DNS_VALUE}\"}]}}]}" > .tmp.json &&
      # when json has been successfully created, send success message
      info "Created .tmp.json with DNS entry" ||
      # when json gave error when creating, stop the script and print fail message
      fail "Failed to create JSON file"
      aws route53 change-resource-record-sets --hosted-zone-id ${HOSTED_ZONE_ID} --change-batch file://.tmp.json >/dev/null 2>&1 &&
      success "Created certificate ${DNS_NAME}" ||
      fail "Unable to create certificate ${DNS_NAME} in ${DOMAIN}"
      # Removing JSON File
      rm .tmp.json
    fi
  else
    error "Hosted zone for ${DOMAIN} does not exist"
  fi
done