/etc/yum.repos.d/salt.repo:
  file.managed:
    - contents: |
        [saltstack-repo]
        name=SaltStack repo for Red Hat Enterprise Linux $releasever
        baseurl=https://repo.saltstack.com/yum/redhat/$releasever/$basearch/latest
        enabled=1
        gpgcheck=1
        gpgkey=https://repo.saltstack.com/yum/redhat/$releasever/$basearch/latest/SALTSTACK-GPG-KEY.pub
               https://repo.saltstack.com/yum/redhat/$releasever/$basearch/latest/base/RPM-GPG-KEY-CentOS-7
