# AWS-ACM-Tool
## What?
A simple script made by Ixor to create certificates in one account and add the DNS entries in ixor.tooling
## Usage
### Create assumerole cache
In order for this script to work properly, you'll have to cache the assumerole data.
For more information about assumerole and how to set it up: [aws-sts-assumerole](https://github.com/rik2803/aws-sts-assumerole)

Create the assumerole cache using `assumerole ixor.tooling-admin [OTP]` and `assumerole [account] [OTP]`
Once you've done this, you should have the files in `~/.assumerole.d/cache`
### Run the script
you can run the script with the following command: `bash ACM_Create.bash [account] [main domain] [extra_domain_1] [extra_domain_2] [extra_domain_x]`
###### **when you have a domain like `*.ixor.be`, you need to put double quotes around it: `"*.ixor.be"`**

### Script explanation
this script will do the following things
1. Check if all the arguments are valid
2. Check if the cache for ixor.tooling-admin and the other account exist
3. Load the cached vars from the account you want to create the certificates on
4. Create a certificate with the domain first given as main domain and the other domains as extra. these will be made in "eu-central-1" and "us-east-1"
`Certificates for CloudFront must be created in "us-east-1"`
5. Wait 10 seconds to let the CNAME Names and CNAME Values generate. Once generated, it will save the names and values in vars
6. Load the cached vars from ixor.tooling-admin (Account where the DNS-Entries are stored for validation)
7. Load the hosted zones in this account in a var
8. Check if the given domains (remove the "*." where needed) are detected in the hosted zones var
9. If the domain matches the hosted zone, it loads the DNS-Entries of that hosted zone
10. Check if the CNAME Name of the certificate matches one of the certificates in the DNS ENtries
11. Create a DNS-Entry if the DNS-Entry for the CNAME Name doesn't exist

### After running the script
After running the script, a certificate has been created. This certificate has a `Pending Validation` status.
This should automatically be validated after about 2 minutes.