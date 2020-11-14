INTRODUCTION
#
AWSVPCB (AWS Virtual Private Cloud Builder) is a set of BASH Shell scripts designed to create a small enterprise IT-like environment in AWS to provide college-level students with hands-on experience individually working on IT problems. These scripts work in conjunction with the Havoc Circus utility which provides AWS images (AMIs) with pre-loaded applications and a method for automatically changing the environment for assignment purposes. These scripts were originally developed by Norbert Monfort and Robert Fortunato for the CTS-4743 Enterprise IT Troubleshooting course taught at FIU (Florida International University) in Miami, Florida.  However, these scripts and the associated Havoc Circus C#.Net packages are open source and free to be used for any purpose. These two components make up what is called the "Clouducate Suite", which we would like to see expand to include additional tools in the future. Included in this repository is a presentation (Clouducate.pdf) which explains and provides an introduction to AWSVPCB and Havoc Circus.  The rest of this document will focus on AWSVPCB.
#
#
#
STRUCTURE OF AWSVPCB
#
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
#
#
CONFIG FILE (vpcb-config) SETTINGS
#
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
# 
#
#
VPC JSON FILES
#
The awsvpcb-scripts.zip file includes a sample json configuration file in the "secfiles/vpc0" directory. AWSVPCB allows for the definition of multiple VPCs (default is vpc0), however, there could only be one defined in AWS for a given AWS account at one time. In addition due to the fact the each time you create a VPC a new OVPN file is generated, it's recommended that you limit the number of VPCs used in one course.  For CTS-4743, for exampe, we only use one VPC for the entire semester and use the assignment json files to adjust the environment. VPCs can be created, registered and destroyed. Registering a VPC entails comparing the dynamic files within the "procs" directory with what is actually in AWS. All VPC json parameters are required, albeit the number of subnets, possibleInstanceNames and PossibleELBs is variable. The sample VPC json file includes all the parameters currently available. The below is a summary of these parameters:
VPC-VPCCIDR(required): The range of IPs availabel for the VPC in CIDR notation

Subnets(required): The number of subnets is flexible, but the DEFAULT and PUBLIC subnets are required and should not be touched
Subnets-SubnetName(required): The name of the subnet
Subnets-SubnetCIDR(required): The IP range for the subnet in CIDR notation
Subnets-SecurityGroup(required): "yes" or "no" as to whether this subnet have an equivalently named Security group controlling it's inbound and outbound traffic
Subnets-RoutingTable(required): "DEFAULT" or "PUBLIC" - all subnets other than the PUBLIC, should use the DEFAULT routing table

PossibleInstanceNames(required): This is necessary to allow the AWSVPCB.VPC.REGISTER script to re-calibrate the scripts registry with what exists in AWS. Simply list the possible instance names that may exist in any assignment to be used with this VPC.

PossibleELBs(required): This is necessary to allow the AWSVPCB.VPC.REGISTER script to re-calibrate the scripts registry with what exists in AWS. Simply list the possible ELB names that may exist in any assignment to be used with this VPC.

DNSIPAddresses(required): This is a list of the IP addresses that will be defined in the AWS Route 53 resolver (DNS server). All AMIs should have these IPs in their config in order to appropriately resolve your private domain's DNS names to IPs.

NATDefinition(required): This is unlikely to need to be changed as this is simply defined to allow Internet access from within the VPC.
NATDefinition-IPAddress(required): IP address for the NAT instance.
NATDefinition-Subnet(required): Subnet for the NAT instance.
NATDefinition-AMI: AMI (AWS Machine Image) for the NAT instance.
#
#
#
ASSIGNMENT JSON FILES
#
The awsvpcb-scripts.zip file includes sample assignment json configuration files in the "secfiles/assignment#" directories (#=1-3). AWSVPCB allows for the definition of multiple assignments (there is no default). Assignments can be created, started, stopped and destoyed. Starting and stopping an assignment preserves all changes made. The option to start and stop an assignment is necessary to allow a student to step away and not unnecessarily use up their allotted AWS credits. The 3 sample assignment json files include all the parameters currently available. Some of these parameters are optional.  The below is a summary of these parameters:

WHAT THE POC TEST BELOW DOES
#
The below "GETTING STARTED - POC TEST" section will use the default awsvpcb-scripts provided to build a VPC with VPN connectivity that includes publicly available Havic Circus AMIs with one or two applications loaded.  This will use static json files pre-loaded in the awsvpcb "secfiles" directory for the VPC and Assignments (1-3 are included) to provide you with examples of what can be configured with AWSVPCB.  This will also use static assignment json files loaded on the Havic Circus AMIs that provide examples of what you can do with Havoc Circus (more info on that within the Havoc Circus Readme). 
#
#
#
GETTING STARTED - POC TEST
1) CREATE TEST STUDENT AWS ACCOUNT - This will be where the VPC is created
  - NOTE: Credit must be provided.  AWS credits should be obtained and added to this account to avoid unnecessary charges.  However, the charges for going through this POC are minimal (under $10) as long as everything is destroyed in the end and it is not kept up and running for hours.
2) DECIDE which PC you are planning to use to access your VPC (Linux, MAC or Windows)
3) INSTALL OPENVPN - This will be used later when the OVPN file is created
  - ON MAC: OpenVPN Connect version 3.1 or higher from the MAC App Store 
  - ON WINDOWS: https://www.ovpn.com/en/guides/windows-openvpn-gui 
4) DECIDE where you are going to run the scripts (must be a Linux or MAC machine) - if using MAC or Linux for the PC where OpenVPN is installed, then it can be the same machine.
5) INSTALL the AWS CLI (version 2) on the chosen machine - follow instructions provided by AWS (https://docs.aws.amazon.com/cli/latest/userguide/install-cliv2.html) and test with following command to make sure you have the proper access: aws ec2 describe-instances
6) DOWNLOAD & EXTRACT the awsvpcb-scripts file onto the machine where the AWS CLI is installed 
7) CD to the root of awsvpcb-scripts directory
6) RUN ./AWSVPCB.CONFIGURE
8) RUN ./AWSVPCB.VPC.CREATE
9) IF NECESSARY, DOWNLOAD the AWSVPCB-client-config.ovpn file created in the "secfiles" directory to the PC you installed the OpenVPN client
10) IMPORT the AWSVPCB-client-config.ovpn into the OpenVPN client
11) IF NECESSARY, DOWNLOAD the ca.crt file in the "secfiles" directory to the PC you installed the OpenVPN client
12) ADD the ca.crt root certificate to the trusted store on your PC (Windows, MAC or Linux)
13) IF NECESSARY, DOWNLOAD other support files from the "secfiles" directory to the PC including:
  - iis1.rdp, iis1.password, iis2.rdp, iis2.password, mssql.rdp, mssql.password, mssql.sa.password, privkey.ppk (if you plan to use putty), privkey.pem (if you plan to use SSH)
13) RUN ./AWSVPCB.ASSIGNMENT.CREATE 1
14) RUN ./AWSVPCB.ASSIGNMENT.START
15) CONNECT with OpenVPN to your AWS VPC using the OVPN connection you just imported
16) TEST the following:
  - RDP to the iis1.awsvpcb.edu server using the iis1.rdp file in the "secfiles" directory
  - RDP to the mssql.awsvpcb.edu server using the mssql.rdp file in the "secfiles" directory
  - SSH to the linux1.awsvpcb.edu server using the privkey.pem file (password is hardcoded to cts4743) or use putty (need to add privkey.ppk to the definition - same password of cts4743)
  - Use SSMS (Windows) or Azure Data Studio (MAC) to connect to the SQL Server instance onn mssql.awsvpcb.edu
  - Use a browser to connect to http://myfiu.awsvpcb.edu and/or http://rainforest.awsvpcb.edu
17) RUN ./AWSVPCB.ASSIGNMENT.STOP  # this would only be necessary if you wanted to get back to this later, else you can run ./AWSVPCB.ASSIGNMENT.DESTROY
#
#
#

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

