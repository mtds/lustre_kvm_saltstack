/etc/yum.repos.d/e2fsprogs.repo:
  file.managed:
    - contents: |
        [e2fsprogs]
        name=Lustre e2fsprogs
        baseurl=https://downloads.hpdd.intel.com/public/e2fsprogs/latest/el7
        enabled=True
        gpgcheck=False
