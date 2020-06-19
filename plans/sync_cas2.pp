plan manage_ca_file::sync_cas2 (
  TargetSpec     $targets,
  TargetSpec     $ca_hosts             = $targets,
  Enum[full,api] $crl_bundle           = 'full',
  Boolean        $restart_puppetserver = false,
) {
  $update_targets = get_targets($targets)
  $ca_targets  = get_targets($ca_hosts)

  $api_ca_data = run_task('manage_ca_file::api_ca_data', $update_targets[0],
    ca_hostnames => $ca_targets.map |$t| { $t.name },
  )[0]

  $full_crl_bundle = $api_ca_data['crl_bundle']

  ## COMMENTING OUT THE LINES BELOW WILL ALLOW THIS PLAN TO WORK SUCCESSFULLY
  $ordered_pem_bundles = {
    'ca_crt'    => manage_ca_file::ordered_ca_bundles($api_ca_data['peer_certs'], $api_ca_data['ca_bundle']),
    'ca_crl'    => manage_ca_file::ordered_crl_bundles($api_ca_data['peer_certs'], $full_crl_bundle),
    'infra_crl' => manage_ca_file::ordered_crl_bundles($api_ca_data['peer_certs'], $api_ca_data['crl_bundle']),
  }

  apply_prep($update_targets)

  # Note that there is a race condition here around the CRL.
  # See https://tickets.puppetlabs.com/browse/SERVER-2550
  apply($update_targets) {
    File {
      ensure => file,
      owner  => 'pe-puppet',
      group  => 'pe-puppet',
      notify => $restart_puppetserver ? {
        true  => Service['pe-puppetserver'],
        false => undef,
      },
    }

    # Question: does Puppet Server need reloading?
    service { 'pe-puppetserver': }
  }

  # Note: agents and compilers will recieve the updated CA bundle and CRL through normal
  # distribution means

  return('Complete')
}