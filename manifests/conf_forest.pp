# Class: windows_ad
#
# Full description of windows_ad::conf_forest here.
#
# This class allow you to configure/unconfigure a windows domain forest
#
# When you use this class please use it with windows_ad directly.
# see the readme file.
#
# === Parameters
#
#
# === Examples
#
#  class{'windows_ad::conf_forest':
#    ensure                    => present,
#    domainname                => 'jre.local',
#    netbiosdomainname         => 'jre',
#    domain               => '6',
#    forestlevel               => '6',
#    globalcatalog             => 'yes',
#    databasepath              => 'c:\\windows\\ntds',
#    logpath                   => 'c:\\windows\\ntds',
#    sysvolpath                => 'c:\\windows\\sysvol',
#    dsrmpassword              => $dsrmpassword,
#    installdns                => 'yes',
#    localadminpassword        => 'password',
#    force                     => true,
#    forceremoval              => true,
#    uninstalldnsrole          => 'yes',
#    demoteoperationmasterrole => true,
#  }
#
# === Authors
#
# Jerome RIVIERE (www.jerome-riviere.re)
#
# === Copyright
#
# Copyright 2014 Jerome RIVIERE.
#
class windows_ad::conf_forest (
  #install parameters
  $ensure                    = $ensure,
  $domainname                = $domainname,
  $netbiosdomainname         = $netbiosdomainname,
  $domain                    = $domain,
  $domainlevel               = $domainlevel,
  $forestlevel               = $forestlevel,
  $globalcatalog             = $globalcatalog,
  $databasepath              = $databasepath,
  $logpath                   = $logpath,
  $sysvolpath                = $sysvolpath,
  $dsrmpassword              = $dsrmpassword,
  $installdns                = $installdns,
  $kernel_ver                = $kernel_ver,
  $timeout                   = 0,
  $configureflag             = $configureflag,
  $installtype               = $installtype,
  $ent_admin_username        = $ent_admin_username,
  $ent_admin_password        = $ent_admin_password,
  $restart                   = $restart,
  $source_dc                 = $source_dc,

  #removal parameters
  $localadminpassword        = $localadminpassword, #admin password required for removal
  $force                     = $force,
  $forceremoval              = $forceremoval,
  $uninstalldnsrole          = $uninstalldnsrole,
  $demoteoperationmasterrole = $demoteoperationmasterrole,
  $site_name                 = $site_name,
){
  validate_bool($configureflag)
  if ($configureflag == true){
    if $force {
      $forcebool = 'true'
    } else {
      $forcebool = 'false'
    }
    if $restart {
      $norestartbool = 'false'
      $reboot_yes_no = 'yes'
    } else {
      $norestartbool = 'true'
      $reboot_yes_no = 'no'
    }
    if $globalcatalog == 'yes' {
      $noglobalcatalogbool = 'false'
    } else {
      $noglobalcatalogbool = 'true'
    }
    if $forceremoval {
      $forceboolremoval = 'true'
    } else {
      $forceboolremoval = 'false'
    }
    if $demoteoperationmasterrole {
      $demoteoperationmasterrolebool = 'true'
    } else {
      $demoteoperationmasterrolebool = 'false'
    }

    # If the operating is server 2012 then run the appropriate powershell commands if not revert back to the cmd commands
    if ($ensure == 'present') {
      case $installtype {
        'forest': {
          if ($installdns == 'yes') {
            if ($kernel_ver =~ /^6\.2|^6\.3/) {
                # Deploy Server 2012 Active Directory
                exec { 'Config ADDS':
                  command  => "Import-Module ADDSDeployment; Install-ADDSForest -Force -DomainName ${domainname} -DomainMode ${domainlevel} -DomainNetbiosName ${netbiosdomainname} -ForestMode ${forestlevel} -DatabasePath ${databasepath} -LogPath ${logpath} -SysvolPath ${sysvolpath} -SafeModeAdministratorPassword (convertto-securestring '${dsrmpassword}' -asplaintext -force) -InstallDns",
                  provider => powershell,
                  onlyif   => "if((gwmi WIN32_ComputerSystem).Domain -eq \'${domainname}\'){exit 1}",
                  timeout  => $timeout,
                }
              } else {
                # Deploy Server 2012 Active Directory Without DNS
                exec { 'Config ADDS':
                  command  => "Import-Module ADDSDeployment; Install-ADDSForest -Force -DomainName ${domainname} -DomainMode ${domainlevel} -DomainNetbiosName ${netbiosdomainname} -ForestMode ${forestlevel} -DatabasePath ${databasepath} -LogPath ${logpath} -SysvolPath ${sysvolpath} -SafeModeAdministratorPassword (convertto-securestring '${dsrmpassword}' -asplaintext -force)",
                  provider => powershell,
                  onlyif   => "if((gwmi WIN32_ComputerSystem).Domain -eq \'${domainname}\'){exit 1}",
                  timeout  => $timeout,
                }
              }
          } else {
            # Deploy Server 2008 R2 Active Directory
            exec { 'Config ADDS 2008':
              command => "cmd.exe /c dcpromo /unattend /InstallDNS:yes /confirmGC:${globalcatalog} /NewDomain:forest /NewDomainDNSName:${domainname} /domain:${domain} /forestLevel:${forestlevel} /ReplicaOrNewDomain:domain /databasePath:${databasepath} /logPath:${logpath} /sysvolPath:${sysvolpath} /SafeModeAdminPassword:${dsrmpassword}",
              path    => 'C:\windows\sysnative',
              unless  => "sc \\\\${::fqdn} query ntds",
              timeout => $timeout,
            }
          }
        }

        'child': {
          if ($installdns == 'yes') {
            if ($kernel_ver =~ /^6\.2|^6\.3/) {

                $domain_elements = split($domainname, '[.]')
                $child_domain = $domain_elements[0]
                $parent_domain = join(delete_at($domain_elements,0), '.')
                $replication_source = $source_dc ? {
                  undef   => '',
                  default => '-ReplicationSourceDC ${source_dc}'
                }

                # Deploy Server 2012 Active Directory
                exec { 'Config ADDS':
                  command  => "Install-ADDSDomain -NoGlobalCatalog:\$${noglobalcatalogbool} -CreateDnsDelegation:\$true -Credential (New-Object PSCredential('${ent_admin_username}',(ConvertTo-SecureString '${ent_admin_password}' -AsPlainText -Force))) -DomainMode ${domainlevel} -DomainType \"ChildDomain\" -InstallDns:\$true -NewDomainName ${child_domain}  -NewDomainNetbiosName ${netbiosdomainname} -ParentDomainName ${parent_domain} -NoRebootOnCompletion:\$${norestartbool} -SiteName \"${site_name}\" -Force:\$true ${replication_source} -SafeModeAdministratorPassword (ConvertTo-SecureString '${dsrmpassword}' -AsPlainText -Force)",
                  provider => powershell,
                  onlyif   => "if ((gwmi WIN32_ComputerSystem).Domain -ne '${domainname}') {exit 0} else {exit 1}",
                  timeout  => $timeout,
                }

              } else {
                # Deploy Server 2012 Active Directory Without DNS
                exec { 'Config ADDS':
                  command  => "Install-ADDSDomain -NoGlobalCatalog:\$${noglobalcatalogbool} -CreateDnsDelegation:\$true -Credential (New-Object PSCredential('${ent_admin_username}',(ConvertTo-SecureString '${ent_admin_password}' -AsPlainText -Force))) -DomainMode ${domainlevel} -DomainType \"ChildDomain\" -InstallDns:\$false -NewDomainName ${child_domain} -NewDomainNetbiosName ${netbiosdomainname} -ParentDomainName ${parent_domain} -NoRebootOnCompletion:\$${norestartbool} -SiteName \"${site_name}\" -Force:\$true -SafeModeAdministratorPassword (ConvertTo-SecureString '${dsrmpassword}' -AsPlainText -Force)",
                  provider => powershell,
                  onlyif   => "if ((gwmi WIN32_ComputerSystem).Domain -ne '${domainname}') {exit 0} else {exit 1}",
                  timeout  => $timeout,
                }
              }
          } else {
            # Deploy Server 2008 R2 Active Directory
            exec { 'Config ADDS 2008':
              command => "cmd.exe /c dcpromo /unattend /confirmGC:${globalcatalog} /NewDomain:child /NewDomainDNSName:${domainname} /ParentDomainDNSName:${parent_domain} /DomainNetbiosName:${netbiosdomainname} /childName:${child_domain} /domain:${domain} /forestLevel:${forestlevel} /DomainLevel:${domainlevel} /ReplicaOrNewDomain:domain /databasePath:${databasepath} /logPath:${logpath} /sysvolPath:${sysvolpath} /SafeModeAdminPassword:${dsrmpassword} /rebootOnCompletion:${reboot_yes_no} /InstallDNS:yes",
              path    => 'C:\windows\sysnative',
              unless  => "sc \\\\${::fqdn} query ntds",
              timeout => $timeout,
            }
          }
        }
      }
    } else { #uninstall AD
      if ($kernel_ver =~ /^6\.2|^6\.3/) {
        if ($localadminpassword != '') {
          exec { 'Uninstall ADDS':
            command     => "Import-Module ADDSDeployment;Uninstall-ADDSDomainController -LocalAdministratorPassword (ConvertTo-SecureString \'${localadminpassword}\' -asplaintext -force) -Force:$${forcebool} -ForceRemoval:$${forceboolremoval} -DemoteOperationMasterRole:$${demoteoperationmasterrolebool} -SkipPreChecks",
            provider    => powershell,
            onlyif      => "if((gwmi WIN32_ComputerSystem).Domain -eq 'WORKGROUP'){exit 1}",
            timeout     => $timeout,
          }
          if ($uninstalldnsrole == 'yes') {
            exec { 'Uninstall DNS Role':
              command   => "Import-Module ServerManager; Remove-WindowsFeature DNS -Restart",
              onlyif    => "Import-Module ServerManager; if (@(Get-WindowsFeature DNS | ?{\$_.Installed -match \'true\'}).count -eq 0) { exit 1 }",
              provider  => powershell,
            }
          }
        }
      } else {
        # uninstall Server 2008 R2 Active Directory -> not tested
        exec { 'Uninstall ADDS 2008':
          command => "cmd.exe /c dcpromo /forceremoval",
          path    => 'C:\windows\sysnative',
          unless  => "sc \\\\${::fqdn} query ntds",
          timeout => $timeout,
        }
      }
    }
  }
}
