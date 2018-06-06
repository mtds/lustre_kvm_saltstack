/etc/yum.repos.d/lustre.repo:
  file.managed:
    - contents: |
        [lustre]
        name=Lustre Fileserver repo
        baseurl=https://downloads.hpdd.intel.com/public/lustre/lustre-2.10.4/el7/server
        enabled=True
        gpgcheck=False
