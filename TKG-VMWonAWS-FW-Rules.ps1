#Replace these variables with your own environment information
###############################################################################
$RefreshToken = "" #Auth Token
$OrgName = "" #Organization Name not ID
$SDDCName = "" #SDDC Name
$TKGNetwork = "10.130.11.0/24" #Network address the Kubernetes Cluster Runs in
$TKGNetworkName = "Tanzu Network Segment" #Name of the Kubernetes Cluster Network
$TKGBootStrapper = "10.10.0.0/16" #Bootstrapper address (Can be single IP or range)
$TKGEndpoint = "10.130.11.10" #TKG Endpoint address (VIP or Load Balancer)
$ImageRegistry = "" #Location of a the container image registery with TKG images. (Empty uses the public repo)
$DNS = "10.130.5.140" #DNS Server Address
$NTP = "10.11.50.12" #NTP Server Address
$LDAPServer = "10.11.3.162" #LDAPS Server for Pinniped/Dex
################################################################################

#import modules needed to communicate with NSX-T and vCenter
Import-Module VMware.VMC.NSXT.psd1
Import-Module VMware.VMC.psd1

#Connect to VMware Cloud on AWS Resources
Connect-Vmc -RefreshToken $RefreshToken 
Connect-NSXTProxy -RefreshToken $RefreshToken -OrgName $OrgName -SDDCName $SDDCName

## Create Firewall Groups
if ($TKGBootStrapper) {
    New-NSXTGroup -GatewayType MGW -Name TKG-Bootstrapper -IPAddress @($TKGBootStrapper)
    New-NSXTGroup -GatewayType CGW -Name TKG-Bootstrapper -IPAddress @($TKGBootStrapper)
}
if ($TKGNetwork) {
    New-NSXTGroup -GatewayType MGW -Name $TKGNetworkName -IPAddress @($TKGNetwork)
    New-NSXTGroup -GatewayType CGW -Name $TKGNetworkName -IPAddress @($TKGNetwork)
}
if ($TKGEndpoint) {
    New-NSXTGroup -GatewayType CGW -Name TKG-Endpoint -IPAddress @($TKGEndpoint)
}
if ($ImageRegistry) {
    New-NSXTGroup -GatewayType CGW -Name TKG-ImageRegistry -IPAddress @($ImageRegistry)
}
if ($DNS) {
    New-NSXTGroup -GatewayType CGW -Name TKG-DNS -IPAddress @($DNS)
}
if ($NTP) {
    New-NSXTGroup -GatewayType CGW -Name TKG-NTP -IPAddress @($NTP)
}
if ($LDAPSERVER) {
    New-NSXTGroup -GatewayType CGW -Name TKG-LDAPS -IPAddress @($LDAPServer) 
}


#Create Firewall Services
New-NSXTServiceDefinition -Name TKG-6443 -DestinationPorts 6443 -Protocol TCP
New-NSXTServiceDefinition -Name TKG-NTP -DestinationPorts 123 -Protocol TCP
New-NSXTServiceDefinition -Name TKG-LDAPS -DestinationPorts 636 -Protocol TCP
New-NSXTServiceDefinition -Name TKG-Auth -DestinationPorts 30167,31234 -Protocol TCP


#Create MGW Firewall Rules
if ($TKGNetworkName) {
    New-NSXTFirewall -GatewayType MGW -Name "TKG-vCenter-Access" -SourceGroup @($TKGNetworkName) -DestinationGroup @("VCENTER") -Service @("HTTPS") -SequenceNumber 0 -Action ALLOW
}

if ($TKGBootStrapper) {
    New-NSXTFirewall -GatewayType MGW -Name "TKG-Bootstrap-vCenter-Access" -SourceGroup @("TKG-Bootstrapper") -DestinationGroup @("VCENTER") -Service @("HTTPS") -SequenceNumber 0 -Action ALLOW
}

# Create CGW Firewall Rules
if ($TKGEndpoint) {
    New-NSXTFirewall -GatewayType CGW -Name "TKG-Bootstrap-Cluster" -SourceGroup @("TKG-Bootstrapper") -DestinationGroup @("TKG-Endpoint") -Service @("TKG-6443") -Logged $false -SequenceNumber 0 -Action ALLOW -InfraScope @("All Uplinks")
}

if ($TKGBootStrapper) {
    New-NSXTFirewall -GatewayType CGW -Name "TKG-Bootstrap-Network" -SourceGroup @("TKG-Bootstrapper") -DestinationGroup @($TKGNetworkName) -Service @("TKG-6443") -Logged $false -SequenceNumber 0 -Action ALLOW -InfraScope @("All Uplinks")
}

if ($TKGNetworkName) {
    New-NSXTFirewall -GatewayType CGW -Name "TKG-Network-Access" -SourceGroup @($TKGNetworkName) -DestinationGroup @($TKGNetworkName) -Service @("ANY") -Logged $false -SequenceNumber 0 -Action ALLOW -InfraScope @("All Uplinks")
}

if ($TKGNetworkName) {
    New-NSXTFirewall -GatewayType CGW -Name "TKG-Network-Outbound-HTTPS" -SourceGroup @($TKGNetworkName) -DestinationGroup @("ANY") -Service @("HTTPS") -Logged $false -SequenceNumber 0 -Action ALLOW -InfraScope @("All Uplinks")
}

if ($ImageRegistry) {
    New-NSXTFirewall -GatewayType CGW -Name "TKG-ImageRegistry-Access" -SourceGroup @($TKGNetworkName) -DestinationGroup @("TKG-ImageRegistry") -Service @("HTTPS") -Logged $false -SequenceNumber 0 -Action ALLOW -InfraScope @("All Uplinks")
}

if ($DNS) {
    New-NSXTFirewall -GatewayType CGW -Name "TKG-DNS-Access" -SourceGroup @($TKGNetworkName) -DestinationGroup @("TKG-DNS") -Service @("DNS") -Logged $false -SequenceNumber 0 -Action ALLOW -InfraScope @("All Uplinks")
}

if ($NTP) {
    New-NSXTFirewall -GatewayType CGW -Name "TKG-NTP-Access" -SourceGroup @($TKGNetworkName) -DestinationGroup @("TKG-NTP") -Service @("NTP") -Logged $false -SequenceNumber 0 -Action ALLOW -InfraScope @("All Uplinks")
}

if ($LDAPServer) {
    New-NSXTFirewall -GatewayType CGW -Name "TKG-LDAPS-Access" -SourceGroup @($TKGNetworkName) -DestinationGroup @("TKG-LDAPS") -Service @("TKG-LDAPS") -Logged $false -SequenceNumber 0 -Action ALLOW -InfraScope @("All Uplinks")

    New-NSXTFirewall -GatewayType CGW -Name "TKG-Auth-Access" -SourceGroup @("Any") -DestinationGroup @("TKG-Endpoint") -Service @("TKG-Auth") -Logged $false -SequenceNumber 0 -Action ALLOW -InfraScope @("All Uplinks")
}



# List the user firewall Rules
#Get-NSXTFirewall -GatewayType MGW
#Get-NSXTFirewall -GatewayType CGW