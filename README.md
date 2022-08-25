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