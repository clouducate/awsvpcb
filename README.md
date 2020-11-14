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
 
 
