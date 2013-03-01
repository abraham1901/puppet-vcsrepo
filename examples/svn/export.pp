$svn_host = "svn.mycompanyname.domain"
$export_file = "test.php"
$admin_password = "verysecretpass123"
$svn_path = "www"
$project = "megaproject"

vcsrepo { "/var/${svn_path}/${export_file}":
  ensure		=> present,
  provider		=> svn,
  export		=> true,
  source		=> "https://${svn_host}/${project}/trunk/${svn_path}/${export_file}",
  basic_auth_username	=> "svnupdater",
  basic_auth_password	=> $admin_password,
}
