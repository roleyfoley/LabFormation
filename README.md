# Build Formation

A little module used to create Lab like VPC's within AWS and manage the state of Instances running in them. 

The module as the commands: 
* Start/Stop-Lab - Used to start/Stop all Ec2 instances within the Lab VPC. Also updates the BasicMgmt Security group to allow the current Public IP that the request is coming from (useful for home based internet connections that change IP often )
* New/Remove-Lab - Using the LabFormation.cform build a VPC,Subnet,SecGroup and Internet Gateway that can be used by someone to have a small scale AWS VPC. 

# Requirements
* Module - AWSPowershell or AWSPowerShell.netCore 
* Access to the Public IP rest service - https://api.ipify.org?format=json ( Not owned or managed by myself)