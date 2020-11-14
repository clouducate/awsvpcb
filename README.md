INTRODUCTION
AWSVPCB (AWS Virtual Private Cloud Builder) is a set of BASH Shell scripts designed to create a small enterprise IT-like environment in AWS to provide college-level students with hands-on experience individually working on IT problems. These scripts work in conjunction with the Havoc Circus utility which provides AWS images (AMIs) with pre-loaded applications and a method for automatically changing the environment for assignment purposes. These scripts were originally developed by Norbert Monfort and Robert Fortunato for the CTS-4743 Enterprise IT Troubleshooting course taught at FIU (Florida International University) in Miami, Florida.  However, these scripts and the associated Havoc Circus C#.Net packages are open source and free to be used for any purpose. These two components make up what is called the "Clouducate Suite", which we would like to see expand to include additional tools in the future. Included in this repository is a presentation (Clouducate.pdf) which explains and provides an introduction to AWSVPCB and Havoc Circus.  The rest of this document will focus on AWSVPCB.

STRUCTURE OF AWSVPCB
The AWSVPCB scripts require a specific directory structure. You can simply download the awsvpcb-scripts.zip file to install this directory structure to get started. The following is an explanation of the directories:
1) Root directory of the scripts - All the scripts that are meant to be executed by the students reside in this directory and are all fully CAPITALIZED. All the other directories are support directories relevant to the instructor, but not to the students. The root directory also includes the the vpcb-config file which provides for a few configuration settings for the scripts.
2) The "procs" directory includes all of the detail code for the scripts as well as some dynamic variable files that start off empty, but are modified as the scripts execute and load the json files as well as build the AWS components.  All "code" resides in this directory and the root directory.
3) The "secfiles" directory includes all the supporting information like:
  - The certificates used by the load balancers
  - The certificates used by the VPN
  - The private key used for the AWS instances
  - The certificate authority certificate for all the above
  - The passwords for all of the instances so that the students can login
  - The password for the database so the that students can login
  - The dynamically generated OVPN file for the students to inmport into their PC for VPN connectivity
  - The dynamic json files and templates used to create and save DNS entries
  - The downloaded VPC and Assignment-level json files used to build the VPC(s) and assignments
 4) The "tempfiles" directory includes temporary dynamically generated files
 5) The "logs" directory includes all of the output for all the scripts run 
 
CONFIG FILE (vpcb-config) SETTINGS
There aren't many settings to worry about in the vpcb-config file and most are self-explantory, but here's the list:
  - COURSE & SEMESTER - These two parameters go hand in hand to determine the name of the log group to be created in Cloudwatch.  If you happen to have multiple sections for a particular course within a semester, then it's recommended that you add the section number to the COURSE parameter.  
  - DOMAIN - This is used to append to all of your server and ELB names.  Consider this your fake companies domain name.  The default is "awsvpcb.edu" and certificates for the VPN, and a couple of ELB (load balancer) names are provided for this domain as well as the CA cert (ca.crt) which is all used to build the VPC and ELBs. However, if you wish to create new ELB names or use a different domain, then you would need to create your own CA and replace all the relevant files in the "secfiles" directory. 
  - AWSCMD - This parameter should not be changed for now.  It was setup to provide for the ability to change the aws command in the future.
  - ENABLE_AWS_LOGGING - This parameter can be set to  "yes" or "no".  If set to "yes", then an AWS access key and secret key with access to your Cloudwatch logs must be provided.
  - MANIFEST_LOCATION - This parameter can be set to "aws" or "local".  If set to "aws", then an AWS access key and secret key with access to your S3 bucket where the VPC and Assignment json files are located.
  - AWS_REGION - The AWS region where you want all of this built
  - AWS_AZ - The AWS availability zone where you want all of this built
  - LOGGING_ACCESS_KEY - The AWS access key to be used for logging to AWS
  - LOGGING_SECRET_KEY - The AWS secret key to be used for logging to AWS
  - MANIFEST_ACCESS_KEY - The AWS access key to be used to download VPC and assignment manifest json files from AWS
  - MANIFEST_SECRET_KEY - The AWS secret key to be used to download VPC and assignment manifest json files from AWS
  - MANIFEST_S3BUCKET - The AWS S3Bucket where the VPC and assignment manifest json files are located in AWS
  
GETTING STARTED
1) CREATE 2 AWS accounts - One for the instructor (needed for AMIs, manifest files, logging, etc.) and another to test how this would work for a student 
2) DECIDE where you are going to run the scripts (must be a Linux or MAC machine)
3) INSTALL the AWS CLI (version 2) on the chosen machine - follow instructions provided by AWS (https://docs.aws.amazon.com/cli/latest/userguide/install-cliv2.html)
4) DOWNLOAD & EXTRACT the awsvpcb-scripts file onto the machine where the AWS CLI is installed 
5) CHOOSE DOMAIN 
   - Use default awsvpcb.edu domain - This limits you to two ELB names (myfiu and rainforest), but other than that, there are now other limitations
   OR
   - Create your own domain and provide the following:
      - Public CA cert for import into student client machines or use public CA (e.g. Sectigo)
      - Client & Server VPN certs and private keys
      - ELB certs and private keys
      - All of these would need to be placed in the "secfiles" directory with the appropriate name (NOTE: the VPN server and client names are currently hardcoded, so you need to replace the files in the secfiles directory)
6) IDENTIFY the AMIs to use:
  - Optionally, create server AMIs to be used for assignments 
  - Havoc Circus AMIs can be used OR publicly available AWS AMIs can be used, but at least one custom AMI is needed for the server that will run Havoc Circus as AWSVPCB DNS servers need to be configured on it. 
  - Maintain any custom AMIs used for the assignments (at least one is needed as noted above)
  - House Havoc Circus assignment dependency files and json files
  - Optionally, house AWSVPCB VPC and assignment json files
  - Optionally, if you wish to enable AWS logging, then IAM user with Cloudwatch access
  - Optionally, if you wish to be able to gather diagnostic information, then same IAM user needs access to be able to create a new S3 bucket 
3) Create VPC and assignment AWSVPCB json files
4) Create Havoc Circus assignment json files
5) Each student needs to create AWS account, be provided AWS credits and preferably a Linux server from which they can run the AWS CLI client
6) Access to AMIs must be granted to students’ AWS accounts

