function Get-Lab { 
    [CmdletBinding()]
    $LabCFNStacks = Get-CFNStack | Where-Object { $_.Tags | Where-Object { $_.Key -eq 'Function' -and $_.Value -eq 'Lab'}} 

    return $LabCFNStacks | Sort-Object -Property CreationTime | Format-table CreationTime,StackName,StackStatus,@{Name="LabState";Expression={ ($_.Tags | Where-Object { $_.Key -eq "LabState"}).Value }}
}

function Start-Lab { 
    [CmdletBinding()]

    $MyPublicIP = (Invoke-RestMethod -Method Get -Uri 'https://api.ipify.org?format=json').IP

    # Get the Lab Stacks 
    $LabCFNStacks = Get-CFNStack | Where-Object { $_.Tags | Where-Object { $_.Key -eq 'Function' -and $_.Value -eq 'Lab'}} 
    
    $AllInstances = New-Object System.Collections.ArrayList
    
    Foreach ( $LabCFNStack in $LabCFNStacks ) { 
        $LabInstances = Get-EC2Instance -Filter @( @{name='vpc-id'; values = @( ($($LabCFNStack.Outputs | Where-Object { $_.OutputKey -eq 'VPCId'})).OutputValue) }, @{name='instance-state-code'; values = @(0,32,48,64,80)} )
        if ( $LabInstances ) {
            $Instance =  Start-EC2Instance @( $($LabInstances.Instances.InstanceId))

            Start-Sleep -Seconds 10
            #Refresh the Lab list so that we can get the public IP
            $LabInstances = Get-EC2Instance -Filter @( @{name='vpc-id'; values = @( ($($LabCFNStack.Outputs | Where-Object { $_.OutputKey -eq 'VPCId'})).OutputValue) } )
            [void]$AllInstances.AddRange( @($($LabInstances.Instances )))
        }
        $StackUpdate = Update-CFNStack -StackName $LabCFNStack.StackName -Parameter @( @{ ParameterKey="ClientIP"; ParameterValue="$($MyPublicIP)/32" } ) `
                                        -TemplateURL https://s3-ap-southeast-2.amazonaws.com/labformation/LabFormation.cform `
                                        -Tag @( @{ Key="Function"; Value="Lab"}, @{ Key="LabState"; Value="Started"} ) 
    }
    
    return $AllInstances | Select-Object @{Name="Name";Expression={ ($_.Tags | Where-Object { $_.Key -eq "Name"}).Value }},@{Name="State";Expression={ $_.State.Name }},InstanceId,VPCId,PublicIpAddress,PrivateIpAddress
}

function Stop-Lab { 
    [CmdletBinding()]
    
    # Get the Lab Stacks 
    $LabCFNStacks = Get-CFNStack | Where-Object { $_.Tags | Where-Object { $_.Key -eq 'Function' -and $_.Value -eq 'Lab'}} 
    
    Foreach ( $LabCFNStack in $LabCFNStacks ) { 
        $LabInstances = Get-EC2Instance -Filter @( @{name='vpc-id'; values = @( ($($LabCFNStack.Outputs | Where-Object { $_.OutputKey -eq 'VPCId'})).OutputValue) } 
        , @{name='instance-state-code'; values = @(16)} ) 
        if ( $LabInstances ) {
            $InstanceStop = Stop-EC2Instance @( $($LabInstances.Instances.InstanceId))
        }
    }

    $SecGroupUpdate = $LAbCFNStacks | Update-CFNStack -Parameter @( @{ ParameterKey="ClientIP"; ParameterValue="10.100.0.1/32" } ) `
                                                        -TemplateURL https://s3-ap-southeast-2.amazonaws.com/labformation/LabFormation.cform `
                                                        -Tag @( @{ Key="Function"; Value="Lab"}, @{ Key="LabState"; Value="Stopped"} ) 

    return "Labs Stopped"
}

function New-Lab { 
    [CmdletBinding()]
    Param 
    (
        [Parameter(Mandatory=$true)][string]$LabName
    )

    $MyPublicIP = (Invoke-RestMethod -Method Get -Uri 'https://api.ipify.org?format=json').IP
    $NewLab = New-CFNStack -StackName $LabName `
             -TemplateURL https://s3-ap-southeast-2.amazonaws.com/labformation/LabFormation.cform `
             -Parameter @( @{ ParameterKey="ClientIP"; ParameterValue="$($MyPublicIP)/32" } )`
             -Tag @( @{ Key="Function"; Value="Lab"}, @{ Key="LabState"; Value="Started"} )
    return $NewLab
}

function Remove-lab { 
    [CmdletBinding()]
    Param 
    (
        [Parameter(Mandatory=$true)][string]$LabName
    )
    $LabSearch = Get-CFNStack | Where-Object {  $_.Tags | Where-Object { $_.Key -eq 'Function' -and $_.Value -eq 'Lab'} } | Where-Object { $_.StackName -eq "$($LabName)"}
    if ( $LabSearch ) { 
        $LabRemove = Remove-CFNStack -StackName $Labname
    } 
    else {
        Write-error "Couldn't find a lab with the name $($LabName)" -ErrorAction Stop
    }
    return "Lab Removed: $($LabName)"
}