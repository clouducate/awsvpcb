INTRODUCTION
#
AWSVPCB (AWS Virtual Private Cloud Builder) is a set of BASH Shell scripts designed to create a small enterprise IT-like environment in AWS to provide college-level students with hands-on experience individually working on IT problems. These scripts have evolved over time and all of the recent updates have focused on their use within the AWS Academy Learner Lab.  The scripts still support running outside of the AWS Academy Learner, but the default configurations would be need to be adjusted.  These scripts work in conjunction with the Havoc Circus utility which provides AWS images (AMIs) with pre-loaded applications and a method for automatically changing the environment for assignment purposes. These scripts were originally developed by Norbert Monfort and Robert Fortunato for the CTS-4743 Enterprise IT Troubleshooting course taught at FIU (Florida International University) in Miami, Florida in 2019.  However, these scripts are open source and free to be used for any purpose. These scripts, the associated AMIs and applications they house make up what is called the "Clouducate Suite", which we continue to work on. Included in this repository is a presentation (Clouducate.pdf) which explains and provides an introduction to AWSVPCB and Havoc Circus and the awsvpcb-setup script with instructions (awsvpcb-setup found at https://github.com/clouducate/awsvpcb/raw/refs/heads/main/awsvpcb-setup) which allows for professors to use the scripts "as is" while still getting support from a central administrator.  The rest of this document will focus on AWSVPCB.
#
#
#
STRUCTURE OF AWSVPCB
#
The AWSVPCB scripts require a specific directory structure. You can simply download the awsvpcb-scripts.zip file to install this directory structure to get started. The following is an explanation of the directories:
1) Root directory of the scripts - All the scripts that are meant to be executed by the students reside in this directory and are all fully CAPITALIZED. All the other directories are support directories relevant to the instructor, but not to the students. The root directory also includes the the vpcb-config file which provides for a few configuration settings for the scripts.
2) The "procs" directory includes all of the detail code for the scripts as well as some dynamic variable files (collectively called the registry) that start off empty, but are modified as the scripts load the json files and build out the AWS components.  All "code" resides in this directory and the root directory.
3) The "secfiles" directory includes all the supporting information like:
  - The certificates and private keys used by the load balancers
  - The certificates and private leys used by the VPN (client & server side)
  - The private key used for the AWS instances
  - The certificate authority certificate for all the above
  - The passwords for all of the instances so that the students can login
  - The password for the database so the that students can login
  - The dynamically generated OVPN file for the students to import into their PC for VPN connectivity
  - The dynamic json files and templates used to create and save DNS entries
  - The downloaded VPC and Assignment-level json files used to build the VPC(s) and assignments (these are in sub-directories)
  - The vpcb-config files for each professor that used the aws-setup script to be able to use the scripts "as is"
 4) The "tempfiles" directory includes temporary dynamically generated files
 5) The "logs" directory includes all of the output for all the scripts run 
#
#
#
CONFIG FILE (vpcb-config) SETTINGS
#
If you have used the awsvpcb-setup script (look at awsvpcb-setup instructions.docx for more information), then you can ignore this section as that utility builds this file for you.  Otherwise, you can hardcode values, if desired. The default UNDEFINED values let the CONFIGURE script know to prompt the student to select their professor and associated vpcb-config file.  Unless you plan to use some legacy functionality or use this outside of the centralized admin, you can ignore this section.
Avialable parameters:
  - INSTITUTION, PROFESSOR, COURSE, SEMESTER, & AVAILABLE_COURSES - By default, these are set to "UNDEFINED" to force prompting the student for professor selection.  However, you can hardcode values for these, if desired, except for AVAILABLE_COURSES as this is only relevant for student selection.
  - AWSVPCB_SEM - Set to DYNAMIC to allow for the dynamic determination of the semester based on the month of the year (e.g., 1-3=SPRING, 4-7=SUMMER, >7=FALL).  Any other value simply avoids this automation and your hardcoded value for SEMESTER will remain as is.
  - ERRORMSG - This is the message provided to students when an error occurs.  The defaul value probably doesn't need to change from "please run ./AWSVPCB.DIAGLOG and let the professor know to review...."
  - DOMAIN - This is used to append to all of your server and ELB names.  Consider this your fake companies domain name.  The default is "awsvpcb.edu" and certificates for the VPN, and a couple of ELB (load balancer) names are provided for this domain as well as the CA cert (ca.crt) which is all used to build the VPC and ELBs. However, if you wish to create new ELB names or use a different domain, then you would need to create your own CA and replace all the relevant files in the "secfiles" directory.
  - AWS_REGION - The AWS region where you want all of this built, however, only the default us-east-1 is supported "as is" because that's where the AMIs reside.
  - PRIMARY_AWS_AZ - The AWS availability zone where you want as primary when not running in multiple AZs. However, it's important to note that US-EAST-1B is included in assignments as secondary AZ for WEB servers & ELBs, but primary can be in any other AZ in US-EAST-1
  - AWSCMD - This parameter should not be changed for now.  It was setup to provide for the ability to change the aws command in the future.
  - DIAGLOG_LAMBDA_URL - URL used when the student runs the DIAGLOG script after an error. (professor specific and generated by the aws-setup script)
  - DIAGLOG_SUPPORT - This parameter can be set to "Y" or "N".  This indicates whether student error logs should also be sent to central admin support.
  - DIAGLOG_LAMBDA_SUPPORT_URL - Central admin support URL used if DAIGLOG_SUPPORT is set to "Y".
  - ENABLE_AWS_LOGGING - This parameter can be set to  "yes" or "no".  If set to "yes", then an AWS access key and secret key with access to your Cloudwatch logs must be provided. Only "no" is supported with AWS Academy.
  - MANIFEST_LOCATION - This parameter can be set to "aws" or "local".  If set to "aws", then an AWS access key and secret key with access to your S3 bucket where the VPC and Assignment json files are located.  Only "local" is supported with AWS Academy.
  - LOGGING_ACCESS_KEY - The AWS access key to be used for logging to AWS (not supported in AWS Academy)
  - LOGGING_SECRET_KEY - The AWS secret key to be used for logging to AWS (not supported in AWS Academy)
  - MANIFEST_ACCESS_KEY - The AWS access key to be used to download VPC and assignment manifest json files from AWS (not supported in AWS Academy)
  - MANIFEST_SECRET_KEY - The AWS secret key to be used to download VPC and assignment manifest json files from AWS (not supported in AWS Academy)
  - MANIFEST_S3BUCKET - The AWS S3Bucket where the VPC and assignment manifest json files are located in AWS (not supported in AWS Academy)
  - DIAGLOG_S3BUCKET - The AWS S3Bucket where diagnostic information will be placed; the LOGGING_ACCESS_KEY must have access to write to this S3Bucket (not supported in AWS Academy)
# 
#
#
MAIN EXECUTABLE SCRIPTS
#
AWSVPCB.CONFIGURE - Reads vpcb-config and configures the base settings within the "procs" directory. Can be rerun as often as needed, but does not need to be run unless a change is made to the vpcb-config file.

AWSVPCB.TEST – Simply tests basic connectivity to AWS.

AWSVPCB.VPC.CREATE – This script optionally accepts a numeric parameter (the VPC number; 0 is the default if no number is provided). The script expects a vpc# directory (where # is the VPC number) to exist in the "secfiles" directory or AWS manifest S3bucket where the vpc.json file can be found and loaded. Using this vpc.json file, this script creates a VPC with associate Internet Gateway, NAT instance, route tables, subnets, security groups, S3Bucket for ELB logs, Client VPN endpoint, Bastion instance (Windows Server - default) OR OVPN file for the OpenVPN client and registers all AWS unique IDs. NOTES:
  - The OVPN configuration still works, but not supported within AWS Academy
  - This script will automatically run the AWSVPCB.VPC.REGISTER script an “AWS-VPCB” tagged VPC already exists in the target AWS account. If this doesn't recover your state, then the AWSVPCB.VPC.DESTROY must be run.

AWSVPCB.VPC.DESTROY – This script will destroy the registered VPC and everything in it.

AWSVPCB.VPC.REGISTER – This script compares the AWS object IDs registered with what exists in AWS to adjust the registry files in the "procs" directory appropriately. The script requests the user to provide an optional assignment number such that all of the assignment components are also registered properly.

AWSVPCB.ASSIGNMENT.CREATE # – This script accepts a mandatory assignment number (no default). The script then stops and destroys existing assignment instances, DNS entries and ELB targets if any exist. The script then expects an assignment# directory (where # is the assignment number)to exist in the "secfiles" directory or AWS manifest S3bucket where the awsvpcb.assignment#.json can be found and loaded. The script then creates assignment instances and firewall rules.

AWSVPCB.ASSIGNMENT.START – Starts instances, Creates ELB (if applicable and just during the first start), Associates Client VPN endpoint to subnet (if VPN is used instead of Bastion server), and Creates Route 53 DNS zones. This scripts can run multiple times without destroying any work.

AWSVPCB.ASSIGNMENT.STOP – Stops instances, Saves Route 53 DNS entries, Destroys Route 53 DNS zone, and Disassociates Client VPN endpoint from subnet (if applicable). This script can run multiple times without destroying work.

AWSVPCB.ASSIGNMENT.DESTROY – Destroys existing assignment ELB and instances. This script is called by AWSVPCB.ASSIGNMENT.CREATE and destroys all the work done on assignment.

AWSVPCB.DIAGLOG - This script gathers all the relevant information from the students AWSVPCB directories and AWS VPC and sends it to an S3 bucket for review. All the files are placed in the S3Bucket as defined in the vpcb-config file.

AWSVPCB.MANIFEST.DISPLAY - This script prompts the user for which manifest to display (VPC or Assignment and the relevant #). The script then reads the designated manifest and displays what was extracted and would be loaded into the registry of the awsvpcb-scripts.  This is a good way to test whether your json is properly formatted and accepted. Note that this does not validate the json, just displays what loading it would do.
#
#
#
VPC JSON FILES
#
The awsvpcb-scripts.zip file includes two json configuration file in the "secfiles/vpc0" and "secfiles/vpc1" directories. AWSVPCB allows for the definition of multiple VPCs (default is vpc0), however, there could only be one defined in AWS for a given AWS account at one time. We typically only have students create one VPC for the entire semester and use the assignment json files to adjust the environment. However, VPCs can be created, registered and destroyed as needed. Registering a VPC entails comparing the dynamic files within the "procs" directory with what is actually in AWS. Most VPC json parameters are required, albeit the number of subnets, possibleInstanceNames and PossibleELBs is variable. The sample VPC json file includes all the parameters currently available. The below is a summary of these parameters:

VPC-VPCCIDR(required): The range of IPs available for the VPC in CIDR notation

Subnets(required): The number of subnets is variable, but the DEFAULT and PUBLIC subnets are required and should not be touched

Subnets-SubnetName(required): The name of the subnet (no spaces allowed)

Subnets-SubnetCIDR(required): The IP range for the subnet in CIDR notation

Subnets-AvailabilityZone(optional): This is only needed if the subnet will reside in an availability zone that’s different from the default as defined in vpcb-config file.

Subnets-SecurityGroup(required): "yes" or "no" as to whether this subnet have an equivalently named Security group controlling it's inbound and outbound traffic

Subnets-RoutingTable(required): "DEFAULT" or "PUBLIC" - all subnets other than the PUBLIC, should use the DEFAULT routing table

Parameters (optional): This option can be used for any type of variable you'd want to setup in one location and save in AWS as a Parameter.  It was added to simplify the update of AMIs by defining them in one place (this vpc.json config) as opposed to the many assignment json configs since these are updated every semester for several reasons (e.g., patching, code updates and even OS upgrades over the years)

Parameter-Name (optional): Name of the Parameter

Parameter-Value (optional): Value of the Parameter

PossibleInstanceNames(required): The number of PossibleInstanceNames is variable, but at least one must exist. This is necessary to allow the AWSVPCB.VPC.REGISTER script to re-calibrate the scripts registry with what exists in AWS. Simply list the possible instance names that may exist in any assignment to be used with this VPC.

PossibleELBs(required): The number of PossibleELBs is variable, but at least one must exist. This is necessary to allow the AWSVPCB.VPC.REGISTER script to re-calibrate the scripts registry with what exists in AWS. Simply list the possible ELB names that may exist in any assignment to be used with this VPC.

NATDefinition(required): This is unlikely to need to be changed as this is simply defined to allow Internet access from within the VPC.

NATDefinition-IPAddress(required): IP address for the NAT instance.

NATDefinition-Subnet(required): Subnet for the NAT instance.

NATDefinition-AMI (required): AMI (AWS Machine Image) for the NAT instance.

BASTIONDefinition (required for "bastion" option): This is unlikely to need to be changed as this is simply defined to allow external access into the VPC.

BASTIONDefinition-IPAddress (required for "bastion" option): IP address for the BASTION instance.

BASTIONDefinition-Subnet (required for "bastion" option): Subnet for the BASTION instance.

BASTIONDefinition-AMI (required for "bastion" option): AMI (AWS Machine Image) for the BASTION instance.

RemoteConnFlag (required): The parameter can be "bastion" or "vpn" to determine how remote access into the VPC will be configured.  Only the "bastion" option is supported within AWS Academy.

VPNDefinition (required for "vpn" option): This option is not supported in AWS Academy.

VPNDefinition-CACert (required for "vpn" option): Defines the CA certificate (included in the secfiles directory) to use for the VPN setup.

VPNDefinition-ConfigFile (required for "vpn" option): Defines the configuration file (included in the secfiles directory) to use for the VPN setup.

VPNDefinition-ClientCIDR (required for "vpn" option): Defines the range of IPs to use for the VPN setup.

ServerPrivateKey (required if Linux EC2 instances are used in assignments): Defines the private key file (included in the secfiles directory) to use for the Linux servers.
#
#
#
ASSIGNMENT MANIFEST JSON FILES
#
The awsvpcb-scripts.zip file includes 17 assignment json configuration files in the "secfiles/assignment#" directories (#=1-17). AWSVPCB allows for the definition of multiple assignments (there is no limit). Assignments can be created, started, stopped and destoyed. Starting and stopping an assignment preserves all changes made. The option to start and stop an assignment is necessary to allow a student to step away and not unnecessarily use up their allotted AWS credits. Assignment json files 1-3 include all the parameters currently available. Some of these parameters are optional.  The below is a summary of these parameters:

Instances(required): The number of instances is variable, but at least one must exist

Instances-InstanceName(required): The name of the instance (no spaces allowed)

Instances-InstanceIP(required): The IP address for this instance.  Must be within the IP range of the subnet

Instances-InstanceSubnet(required): The subnet for the instance. Must be a subnet defined in the VPC.json file

Instances-InstanceAMI(required): The AMI (AWS Machine Image) for this instance OR the Parameter that refers to the AMI. If the AMI is private, then it must be shared with the student's AWS account

Instances-InstanceSecGroup(required): The security group assigned to the instance. Must be a security group defined in the VPC.json file

Instances-InstanceType(required): The type/size of the instance. While anything can be chosen here, please be aware that only type t2.micro is currently covered by the AWS "free tier", which allows for many more hours of usage without chewing up a lot of AWS credits.

Instances-InstanceUserDataFile(optional): If you wish to execute code after startup to manipulate the environment to create a scenario, then this parameter can point to the script to run after the server starts

Instances-StartPreference(optional): Valid values are "first" and "last".  Although this can be used for any purpose, it is only necessary if using the Havoc Circus Service, in which case the server that executes this service should be set to "first" 

Instances-StopPreference(optional): Valid values are "first" and "last".  Although this can be used for any purpose, it is only necessary if using the Havoc Circus Service, in which case the server that executes this service should be set to "last"

FirewallRules(optional): Syntactically, Firewall Rules do not need to be provided and there is no limit as to how many are provided. However, if rules are not provided, then no access will be allowed into a security group, so generally at least one inbound and one outbound rule per security group is needed to make things functional.

FirewallRules-SecurityGroup(required): The security group to which this particular firewall rule applies

FirewallRules-RuleType(required): Must be "inbound" or "outbound"

FirewallRules-Protocol(required): Can be "all", "udp", "tcp" or "icmp"

FirewallRules-Port(required): Can be "all" or specific port number or port range with hyphen in between (e.g. "137-139")

FirewallRules-SourceGroup(required): The source (for "inbound" rules) or destination (for "outbound" rules) for this firewall rule in CIDR notation 

HavocCircusUsed(required): This must be "true" or "false" to indicate whether the Havoc Circus service should be started.  Use of this service is not included in any samples as it's considered a legacy feature.

DNSEntriesFile(required): This is the location of the json file that includes the DNS entries to apply to Route 53 when the assignment is created.  The path is relative to the "secfiles" directory and/or the AWS S3 bucket where the manifest exists

ELBs(optional): Only required if ELBs are defined.  NOTE: There is a log automatically created for each ELB within an S3Bucket within the student's AWS account that will include all the requests into that ELB (equivalent to a web access log). There is also a DNS entry automatically created for the ELB.

ELBs-ELBName(required): The name of the ELB. There should be an SSL certificate (.crt file) and private key (.pkey file) in the "secfiles" directory with this name and the chosen domain appended (e.g. rainforest.awsvpcb.edu.crt and rainforest.awsvpcb.edu.pkey where rainforest is the ELBName and awsvpcb.edu is the DOMAIN).

ELBs-ListenerProtocol(optional): The default is HTTPS. At this time, no other option is supported, although support for HTTP is being built to avoid need for certificates.

ELBs-ListenerPort(optional): The default is 443. Any value recognized by AWS is accepted.

ELBs-InstanceProtocol(optional): The default is HTTP. Any value recognized by AWS is accepted.

ELBs-InstancePort(optional): The default is 80. Any value recognized by AWS is accepted.

ELBs-ELBSecGroupName(optional): The security group to apply to the ELB.  The default is ELB. The name chosen must be a valid security group as defined in the VPC JSON file

ELBs-HealthCheckTargetProtocol(optional): The default is HTTP. This will be the protocol AWS uses to validate that the target instances are active. Only HTTP and HTTPS are accepted.

ELBs-HealthCheckTargetPort(optional): The default is 80. This will be the port AWS uses to validate that the target instances are active. Any number under 65535 is accepted.

ELBs-HealthCheckTargetPath(optional): The default is “/”. This the URL AWS uses to validate that the target instances are active. 

ELBs-HealthCheckInterval(optional): The default is 5. This indicates how often AWS will execute the Health Check (in secs). Any value recognized by AWS is accepted.

ELBs-HealthCheckTimeout(optional): The default is 3. This indicates how long (in secs) before AWS considers a health check as timed out (failed). Any value recognized by AWS is accepted.

ELBs-HealthCheckUnhealthyThreshold(optional): The default is 2. This indicates how many health checks must fail for the target instance to be taken out offline. Any value recognized by AWS is accepted.

ELBs-HealthCheckHealthyThreshold(optinal): The default is 2. This indicates how many health checks must succeed for the target instance to be brought back online. Any value recognized by AWS is accepted.

ELBs-EnableSessionStickiness(optinal): The default is N for "no". This indicates whether the load balancer should enable cookie-based session stickiness such that sessions remain on the same backend server. N for "no" or Y for "yes" are accepted.

ELBs-ELBSubnets(required): The number of subnets is variable, but at least one is required.

ELBs-ELBSubnets-SubnetName(required): The name of a subnet where to place an instance for the ELB.  Must be a subnet defined in the vpc.

ELBs-ELBInstances(required): The number of instances is variable, but at least one instance is required.

ELBs-ELBInstances-InstanceName(required): The name of a target instance for the ELB.  Must be an instance defined in the assignment.
#
#
#
ASSIGNMENT DNS JSON FILES
#
The awsvpcb-scripts.zip file includes sample assignment DNS json configuration files in the "secfiles/assignment#" directories (#=1-17). AWSVPCB allows for each assignment to include it's own set of DNS entries for the servers and or other components. The DNS json file must be configured within the assignment json file.  Thus, there could be one centralized DNS json config file used for multiple assignments, if desired. The format of the DNS json configuration file is dictated by AWS as it is loaded directyly without modification. Any parameters accepted by AWS would be accepted in this file.  Please refer to https://docs.aws.amazon.com/cli/latest/reference/route53/change-resource-record-sets.html for available json elements.
#
#
#
WHAT THE POC TEST BELOW DOES
#
The below "GETTING STARTED - POC TEST" section will use the default awsvpcb-scripts provided to build a VPC with VPN connectivity that includes publicly available Havic Circus AMIs with one or two applications loaded.  This will use static json files pre-loaded in the awsvpcb "secfiles" directory for the VPC and Assignments (1-3 are included) to provide you with examples of what can be configured with AWSVPCB.  This will also use static assignment json files loaded on the Havic Circus AMIs that provide examples of what you can do with Havoc Circus (more info on that within the Havoc Circus Readme). 
#
#
#
GETTING STARTED - POC TEST
1) CREATE TEST STUDENT AWS ACCOUNT - This will be where the VPC is created 
  - NOTE: At this time, this cannot be an AWS Educate Starter account as such accounts do not support VPN connectivity
  - NOTE: Credit card must be provided.  AWS credits should be obtained and added to this account to avoid unnecessary charges.  However, the charges for going through this POC are minimal (under $10) as long as everything is destroyed in the end and it is not kept up and running for hours.
2) DECIDE which PC you are planning to use to access your VPC (Linux, MAC or Windows)
3) INSTALL OPENVPN - This will be used later when the OVPN file is created
  - ON MAC: OpenVPN Connect version 3.1 or higher from the MAC App Store 
  - ON WINDOWS: https://www.ovpn.com/en/guides/windows-openvpn-gui 
4) DECIDE where you are going to run the scripts (must be a Linux or MAC machine) - if using MAC or Linux for the PC where OpenVPN is installed, then it can be the same machine.
5) INSTALL the AWS CLI (version 2) on the chosen machine where the scripts will run - follow instructions provided by AWS (https://docs.aws.amazon.com/cli/latest/userguide/install-cliv2.html) and test with following command to make sure you have the proper access: aws ec2 describe-instances
6) DOWNLOAD & EXTRACT the awsvpcb-scripts file onto the machine where the AWS CLI is installed 
7) CD to the root of awsvpcb-scripts directory
6) RUN ./AWSVPCB.CONFIGURE
8) RUN ./AWSVPCB.VPC.CREATE
9) IF NECESSARY, DOWNLOAD the AWSVPCB-client-config.ovpn file created in the "secfiles" directory by the AWSVPCB.VPC.CREATE script to the PC where you installed the OpenVPN client.  If the scripts reside on the same machine, then this is unnecessary.
10) IMPORT the AWSVPCB-client-config.ovpn into the OpenVPN client
11) IF NECESSARY, DOWNLOAD the ca.crt file in the "secfiles" directory to the PC you installed the OpenVPN client. Again, if the scripts reside on the same machine, then this is unnecessary.
12) ADD the ca.crt root certificate to the trusted store on your PC (Windows, MAC or Linux)
13) IF NECESSARY, DOWNLOAD other support files from the "secfiles" directory to the PC including:
  - iis1.rdp, iis1.password, iis2.rdp, iis2.password, mssql.rdp, mssql.password, mssql.sa.password, privkey.ppk (if you plan to use putty), privkey.pem (if you plan to use SSH)
13) RUN ./AWSVPCB.ASSIGNMENT.CREATE 1
14) RUN ./AWSVPCB.ASSIGNMENT.START
15) CONNECT with OpenVPN to your AWS VPC using the OVPN connection you just imported
16) TEST the following:
  - RDP to the iis1.awsvpcb.edu server using the iis1.rdp file in the "secfiles" directory.  If using a MAC for the VPN connectivity, then download Microsoft Remote Desktop 10 or higher from the MAC App Store.
  - RDP to the mssql.awsvpcb.edu server using the mssql.rdp file in the "secfiles" directory. If using a MAC for the VPN connectivity, then download Microsoft Remote Desktop 10 or higher from the MAC App Store.
  - SSH to the linux1.awsvpcb.edu server using the privkey.pem file (password is hardcoded to cts4743) or use putty (need to add privkey.ppk to the definition - same password of cts4743)
  - Use SSMS (Windows) or Azure Data Studio (MAC) to connect to the SQL Server instance on mssql.awsvpcb.edu
  - Use a browser to connect to http://myfiu.awsvpcb.edu (assignments 2 & 3) and/or http://rainforest.awsvpcb.edu (assignments 1 & 3)
17) RUN ./AWSVPCB.ASSIGNMENT.STOP  # this would only be necessary if you wanted to get back to this later, else you can run ./AWSVPCB.ASSIGNMENT.DESTROY
#
#
#
NEXT STEPS FOR YOUR COURSE
1) MAP OUT TARGET ENVIRONMENT 
  - What AMIs do you plan to use? Are the default AMIs provided sufficient or do you want to take those and create custom AMIs? 
  - What applications will the students be testing? Are the default rainforest and myfiu applications sufficient or do I want to build.use others? 
  - What do you want your VPC to look like (IP range, subnets, possible instances, possible ELBs)?  
  - What do you want your assignments to look like (instances, firewall rules, DNS entries, ELBs)? NOTE: In order to use Havoc Circus, at least one of the AMIs must be Windows with the Havoc Circus service pre-loaded and pointing to your Havoc Circus manifest location locally on the server or in AWS.
  - What do you want your assignments to do (e.g. setup a security vulnerability or break the environment in some way)?
2) CHOOSE DOMAIN 
   - Use default awsvpcb.edu domain - This limits you to two ELB names (myfiu and rainforest), but other than that, there are now other limitations
   OR
   - Create your own domain and provide the following:
      - Public CA cert for import into student client machines or use public CA (e.g. Sectigo)
      - Client & Server VPN certs and private keys
      - ELB certs and private keys
      - All of these would need to be placed in the "secfiles" directory with the appropriate name (NOTE: the VPN server and client names are currently hardcoded, so you need to replace the files in the secfiles directory)
3) SETUP INSTRUCTOR AWS ACCOUNT (optional).  This would be needed if you wanted to do any of the following:
  - Host custom AMIs for the assignments that will not be publicly available 
  - House Havoc Circus assignment dependency files and manifest json files
  - House AWSVPCB VPC and assignment json files
  - If you wish to enable AWS logging, then IAM user with Cloudwatch access
  - If you wish to be able to gather diagnostic information, then same IAM user needs access to be able to create a new S3 bucket 
4) CREATE your VPC and assignment AWSVPCB json files
5) CREATE Havoc Circus assignment json files
6) TEST a lot
7) CREATE instructions for students to create their own AWS account
8) PROVIDE AWS credits and preferably a shared/University controlled Linux server from which the students can run the AWS CLI client
9) IF USING CUSTOM/PRIVATE AMIs, the grant access to students’ AWS accounts
