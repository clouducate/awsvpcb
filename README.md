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
  - DIAGLOG_S3BUCKET - The AWS S3Bucket where diagnostic information will be placed; the LOGGING_ACCESS_KEY must have access to write to this S3Bucket
# 
#
#
MAIN EXECUTABLE SCRIPTS
#
AWSVPCB.CONFIGURE - Reads vpcb-config and configures the base settings within the "procs" directory. Can be rerun as often as needed, but does not need to be run unless a change is made to the vpcb-config file.
AWSVPCB.TEST – Simply tests basic connectivity to AWS.
AWSVPCB.VPC.CREATE – This script optionally accepts a numeric parameter (the VPC number; 0 is the default if no number is provided). The script expects a vpc# directory (where # is the VPC number) to exist in the "secfiles" directory or AWS manifest S3bucket where the vpc.json file can be found and loaded. Using this vpc.json file, this script creates a VPC with associate Internet Gateway, NAT instance, route tables, subnets, security groups, S3Bucket for ELB logs, Client VPN endpoint, OVPN file for the OpenVPN client and registers all AWS unique IDs. This script will fail if a “AWS-VPCB” tagged VPC already exists in the target AWS account. In order to rerun this script, the AWSVPCB.VPC.DESTROY must be run first.
AWSVPCB.VPC.DESTROY – This script will destroy the registered VPC and everything in it.
AWSVPCB.VPC.REGISTER – This script compares the AWS object IDs registered with what exists in AWS to adjust the registry files in the "procs" directory appropriately. The script requests the user to provide an optional assignment number such that all of the assignment components are also registered properly.
AWSVPCB.ASSIGNMENT.CREATE # – This script accepts a mandatory assignment number (no default). The script then stops and destroys existing assignment instances, DNS entries and ELB targets if any exist. The script then expects an assignment# directory (where # is the assignment number)to exist in the "secfiles" directory or AWS manifest S3bucket where the awsvpcb.assignment#.json can be found and loaded. The script then creates assignment instances and firewall rules.
AWSVPCB.ASSIGNMENT.START – Starts instances, Creates ELB (if applicable and just during the first start), Associates Client VPN endpoint to subnet, Creates Route 53 DNS zone and entries, Creates Route 53 Inbound endpoints. This scripts can run multiple times without destroying any work.
AWSVPCB.ASSIGNMENT.STOP – Stops instances, Saves Route 53 DNS entries, Destroys Route 53 DNS zone, Disassociate Client VPN endpoint from subnet, Deletes Route 53 Inbound Endpoints. This script can run multiple times without destroying work.
AWSVPCB.ASSIGNMENT.DESTROY – Destroys existing assignment ELB and instances. This script is called by AWSVPCB.ASSIGNMENT.CREATE and destroys all the work done on assignment.
AWSVPCB.DIAGLOG - This script gathers all the relevant information from the students AWSVPCB directories and AWS VPC and sends it to an S3 bucket for review. All the files are placed in the S3Bucket defined in the vpcb-config file.
AWSVPCB.MANIFEST.DISPLAY - This script pormpts the user for which manifest to display (VPC or Assignment and the relevant #). The script then reads the designated manifest and displays what was extracted and would be loaded into the registry of the awsvpcb-scripts.  This is a good way to test whether your json is properly formatted and accepted. Note that this does not validate the json, just displays what loading it would do.
#
#
#
VPC JSON FILES
#
The awsvpcb-scripts.zip file includes a sample json configuration file in the "secfiles/vpc0" directory. AWSVPCB allows for the definition of multiple VPCs (default is vpc0), however, there could only be one defined in AWS for a given AWS account at one time. In addition due to the fact the each time you create a VPC a new OVPN file is generated, it's recommended that you limit the number of VPCs used in one course.  For CTS-4743, for exampe, we only use one VPC for the entire semester and use the assignment json files to adjust the environment. VPCs can be created, registered and destroyed. Registering a VPC entails comparing the dynamic files within the "procs" directory with what is actually in AWS. All VPC json parameters are required, albeit the number of subnets, possibleInstanceNames and PossibleELBs is variable. The sample VPC json file includes all the parameters currently available. The below is a summary of these parameters:
VPC-VPCCIDR(required): The range of IPs available for the VPC in CIDR notation

Subnets(required): The number of subnets is variable, but the DEFAULT and PUBLIC subnets are required and should not be touched
Subnets-SubnetName(required): The name of the subnet (no spaces allowed)
Subnets-SubnetCIDR(required): The IP range for the subnet in CIDR notation
Subnets-SecurityGroup(required): "yes" or "no" as to whether this subnet have an equivalently named Security group controlling it's inbound and outbound traffic
Subnets-RoutingTable(required): "DEFAULT" or "PUBLIC" - all subnets other than the PUBLIC, should use the DEFAULT routing table

PossibleInstanceNames(required): The number of PossibleInstanceNames is variable, but at least one must exist. This is necessary to allow the AWSVPCB.VPC.REGISTER script to re-calibrate the scripts registry with what exists in AWS. Simply list the possible instance names that may exist in any assignment to be used with this VPC.

PossibleELBs(required): The number of PossibleELBs is variable, but at least one must exist. This is necessary to allow the AWSVPCB.VPC.REGISTER script to re-calibrate the scripts registry with what exists in AWS. Simply list the possible ELB names that may exist in any assignment to be used with this VPC.

DNSIPAddresses(required): This is a list of the IP addresses that will be defined in the AWS Route 53 resolver (DNS server). All AMIs should have these IPs in their config in order to appropriately resolve your private domain's DNS names to IPs.

NATDefinition(required): This is unlikely to need to be changed as this is simply defined to allow Internet access from within the VPC.
NATDefinition-IPAddress(required): IP address for the NAT instance.
NATDefinition-Subnet(required): Subnet for the NAT instance.
NATDefinition-AMI: AMI (AWS Machine Image) for the NAT instance.
#
#
#
ASSIGNMENT MANIFEST JSON FILES
#
The awsvpcb-scripts.zip file includes sample assignment json configuration files in the "secfiles/assignment#" directories (#=1-3). AWSVPCB allows for the definition of multiple assignments (there is no default). Assignments can be created, started, stopped and destoyed. Starting and stopping an assignment preserves all changes made. The option to start and stop an assignment is necessary to allow a student to step away and not unnecessarily use up their allotted AWS credits. The 3 sample assignment json files include all the parameters currently available. Some of these parameters are optional.  The below is a summary of these parameters:
Instances(required): The number of instances is variable, but at least one must exist
Instances-InstanceName(required): The name of the instance (no spaces allowed)
Instances-InstanceIP(required): The IP address for this instance.  Must be within the IP range of the subnet
Instances-InstanceSubnet(required): The subnet for the instance. Must be a subnet defined in the VPC.json file
Instances-InstanceAMI(required): The AMI (AWS Machine Image) for this instance. If the AMI is private, then it must be shared with the student's AWS account
Instances-InstanceType(required): The type/size of the instance. While anything can be chosen here, please be aware that only type t2.micro is currently covered by the AWS "free tier", which allows for many more hours of usage without chewing up a lot of AWS credits.
Instances-StartPreference(optional): Although this can be used for any purpose, it is only necessary for the server that executes the Havoc Circus service and should be set to "first" ("last" is also an available option, but will cause problems if used for the instance running the Havoc Circus service)
Instances-StopPreference(optional): Although this can be used for any purpose, it is only necessary for the server that executes the Havoc Circus service and should be set to "last" ("first" is also an available option, but will cause problems if used for the instance running the Havoc Circus service)

FirewallRules(optional): Syntactically, Firewall Rules do not need to be provided and there is no limit as to how many are provided. However, if rules are not provided, then no access will be allowed into a security group, so generally at least one inbound and one outbound rule per security group is needed to make things functional.
FirewallRules-SecurityGroup(required): The security group to which this particular firewall rule applies
FirewallRules-RuleType(required): Must be "inbound" or "outbound"
FirewallRules-Protocol(required): Can be "all", "udp", "tcp" or "icmp"
FirewallRules-Port(required): Can be "all" or specific port number or port range with hyphen in between (e.g. "137-139")
FirewallRules-SourceGroup(required): The source (for "inbound" rules) or destination (for "outbound" rules) for this firewall rule in CIDR notation 

DNSEntriesFile(required): This is the location of the json file that includes the DNS entries to apply to Route 53 when the assignment is created.  The path is relative to the "secfiles" directory and/or the AWS S3 bucket where the manifest exists

ELBs(optional): Only required if ELBs are defined.  NOTE: There is a log automatically created for each ELB within an S3Bucket within the student's AWS account that will include all the requests into that ELB (equivalent to a web access log). There is also a DNS entry automatically created for the ELB.
ELBs-ELBName(required): The name of the ELB. There should be an SSL certificate (.crt file) and private key (.pkey file) in the "secfiles" directory with this name and the chosen domain appended (e.g. rainforest.awsvpcb.edu.crt and rainforest.awsvpcb.edu.pkey where rainforest is the ELBName and awsvpcb.edu is the DOMAIN).
ELBs-ListenerProtocol(optional): The default is HTTPS. At this time, no other option is supported, although support for HTTP is being built to avoid need for certificates.
ELBs-ListenerPort(optional): The default is 443. Any value recognized by AWS is accepted.
ELBs-InstanceProtocol(optional): The default is HTTP. Any value recognized by AWS is accepted.
ELBs-InstancePort(optional): The default is 80. Any value recognized by AWS is accepted.
ELBs-ELBSubnet(optional): The default is ELB. The name chosen must be a valid subnet as defined in the VPC json file
ELBs-HealthCheckTarget(optional): The default is TCP:80. This will be what AWS uses to validate that the target instances are active. Any value recognized by AWS is accepted.
ELBs-HealthCheckInterval(optional): The default is 5. This indicates how often AWS will execute the Health Check (in secs). Any value recognized by AWS is accepted.
ELBs-HealthCheckTimeout(optional): The default is 3. This indicates how long (in secs) before AWS considers a health check as timed out (failed). Any value recognized by AWS is accepted.
ELBs-HealthCheckUnhealthyThreshold(optional): The default is 2. This indicates how many health checks must fail for the target instance to be taken out offline. Any value recognized by AWS is accepted.
ELBs-HealthCheckHealthyThreshold(optinal): The default is 2. This indicates how many health checks must succeed for the target instance to be brought back online. Any value recognized by AWS is accepted.
ELBs-ELBInstances(required): The number of instances is variable, but at least one instance is required.
ELBs-ELBInstances-InstanceName(required): The name of a target instance for the ELB.  Must be an instance defined in the assignment.
#
#
#
ASSIGNMENT DNS JSON FILES
#
The awsvpcb-scripts.zip file includes sample assignment DNS json configuration files in the "secfiles/assignment#" directories (#=1-3). AWSVPCB allows for each assignment to include it's own set of DNS entries for the servers and or other components. The DNS json file must be configured within the assignment json file.  Thus, there could be one centralized DNS json config file used for multiple assignments, if desired. The format of the DNS json configuration file is dictated by AWS as it is loaded directyly without modification. Any parameters accepted by AWS would be accepted in this file.  Please refer to https://docs.aws.amazon.com/cli/latest/reference/route53/change-resource-record-sets.html for available json elements.
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

