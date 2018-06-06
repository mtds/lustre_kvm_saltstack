base:
  '*':
     - yum_saltstack
  'lxfs*.devops.test':
     - yum_lustre_fs_repo
     - yum_e2fsprogs_repo
     - lustre_mds_oss
  'lxmds*.devops.test':
     - yum_lustre_fs_repo
     - yum_e2fsprogs_repo
     - lustre_mds_oss
  'lxb*.devops.test':
     - yum_lustre_client_repo
     - lustre_client
