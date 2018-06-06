lustre_package:
  pkg.installed:
    - pkgs:
      - e2fsprogs.x86_64
      - e2fsprogs-libs.x86_64
      - kmod-lustre.x86_64
      - kmod-lustre-osd-ldiskfs.x86_64

{% if grains['fqdn'] == 'lxmds01.devops.test' %}
/lustre/testfs/mdt:
  file.directory:
    - user: root
    - group: root
    - dir_mode: 755
    - makedirs: true
{% endif %}

{% if grains['fqdn'] == 'lxfs02.devops.test' or grains['fqdn'] == 'lxfs03.devops.test' %}
/lustre/OST:
  file.directory:
    - user: root
    - group: root
    - dir_mode: 755
    - makedirs: true
{% endif %}

{% if 'el7_lustre.x86_64' in grains["kernelrelease"] %}
lustre_tools:
  pkg.installed:
   - pkgs:
     - lustre
{% endif %}

