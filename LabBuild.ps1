$MyPublicIP = (Invoke-RestMethod -Method Get -Uri 'https://api.ipify.org?format=json').IP
Set-DefaultAWSRegion -Region ap-southeast-2

function Start-Lab { 
    [CmdletBinding()]
    Param 
    (
        [string]$MyPublicIP=$MyPublicIP,
        [string]$KeyPairName=$KeyPairName
    )

    # Get the Lab Stacks 
    $LabCFNStacks = Get-CFNStack | Where-Object { $_.Tags | Where-Object { $_.Key -eq 'Function' -and $_.Value -eq 'Lab'}} 
    
    Foreach ( $LabCFNStack in $LabCFNStacks ) { 
        $LabInstances = Get-EC2Instance -Filter @( @{name='vpc-id'; values = @( ($($LabCFNStack.Outputs | Where-Object { $_.OutputKey -eq 'VPCId'})).OutputValue) }, @{name='instance-state-code'; values = @(0,32,48,64,80)} )
        if ( $LabInstances ) {
            Start-EC2Instance $LabInstances
        }
    }
    
    $SecGroupUpdate = $LAbCFNStacks | Update-CFNStack -Parameter @( @{ ParameterKey="ClientIP"; ParameterValue="$($MyPublicIP)/32" } ) -TemplateURL https://s3-ap-southeast-2.amazonaws.com/labformation/LabFormation.cform 
    
    return $LabInstances 
}

function Stop-Lab { 
    
    # Get the Lab Stacks 
    $LabCFNStacks = Get-CFNStack | Where-Object { $_.Tags | Where-Object { $_.Key -eq 'Function' -and $_.Value -eq 'Lab'}} 
    
    Foreach ( $LabCFNStack in $LabCFNStacks ) { 
        $LabInstances = Get-EC2Instance -Filter @( @{name='vpc-id'; values = @( ($($LabCFNStack.Outputs | Where-Object { $_.OutputKey -eq 'VPCId'})).OutputValue) } 
        , @{name='instance-state-code'; values = @(16)} ) 
        if ( $LabInstances ) {
            Stop-EC2Instance $LabInstances
        }
    }

    $SecGroupUpdate = $LAbCFNStacks | Update-CFNStack -Parameter @( @{ ParameterKey="ClientIP"; ParameterValue="10.100.0.1/32" } ) -TemplateURL https://s3-ap-southeast-2.amazonaws.com/labformation/LabFormation.cform 

    return "Labs Stopped"
}

function New-Lab { 
    [CmdletBinding()]
    Param 
    (
        [Parameter(Mandatory=$true)][string]$LabName,
        [string]$MyPublicIP=$MyPublicIP,
        [string]$KeyPairName=$KeyPairName
    )


    $NewLab = New-CFNStack -StackName $LabName `
             -TemplateURL https://s3-ap-southeast-2.amazonaws.com/labformation/LabFormation.cform `
             -Parameter @( @{ ParameterKey="ClientIP"; ParameterValue="$($MyPublicIP)/32" } )`
             -Tag @( @{ Key="Function"; Value="Lab"} ) 
    return $NewLab
}

function Get-Lab { 
    $LabCFNStacks = Get-CFNStack | Where-Object { $_.Tags | Where-Object { $_.Key -eq 'Function' -and $_.Value -eq 'Lab'}} 

    return $LabCFNStacks | Sort-Object -Property CreationTime | Format-table CreationTime,StackName,StackStatus
}