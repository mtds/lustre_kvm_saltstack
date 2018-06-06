/etc/yum.repos.d/lustre.repo:
  file.managed:
    - contents: |
        [lustre-client]
        name=Lustre client repo
        baseurl=https://downloads.hpdd.intel.com/public/lustre/lustre-2.10.4/el7/client
        enabled=True
        gpgcheck=False
