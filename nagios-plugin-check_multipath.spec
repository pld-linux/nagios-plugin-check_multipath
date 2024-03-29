%define		plugin	check_multipath
Summary:	Nagios plugin to check the state of Linux device mapper multipath devices
Summary(pl.UTF-8):	Wtyczka Nagiosa do sprawdzania stanu urządzeń multipath device mappera
Name:		nagios-plugin-%{plugin}
Version:	1.2
Release:	2
License:	GPL v2
Group:		Networking
Source0:	%{name}.sh
URL:		http://www.nagiosexchange.org/cgi-bin/page.cgi?g=Detailed/1996.html
Requires(post,postun):	sudo
Requires:	awk
Requires:	multipath-tools
Requires:	nagios-core
Requires:	nagios-plugins-libs
Requires:	sudo
BuildArch:	noarch
BuildRoot:	%{tmpdir}/%{name}-%{version}-root-%(id -u -n)

%define		plugindir	%{_prefix}/lib/nagios/plugins
%define		_sysconfdir	/etc/nagios/plugins

%description
Nagios plugin to check the state of Linux device mapper multipath
devices.

%description -l pl.UTF-8
Wtyczka Nagiosa do sprawdzania stanu urządzeń multipath linuksowego
device mappera.

%prep
%setup -qcT
install %{SOURCE0} %{plugin}

cat > nagios.cfg <<'EOF'
# Usage:
# %{plugin}
define command {
	command_name    %{plugin}
	command_line    %{plugindir}/%{plugin}
}

define service {
	use                     generic-service
	name                    multipath
	service_description     multipath
	register                0

	normal_check_interval   15
	notification_interval   300

	check_command           check_multipath
}
EOF

%install
rm -rf $RPM_BUILD_ROOT
install -d $RPM_BUILD_ROOT{%{_sysconfdir},%{plugindir}}
install %{plugin} $RPM_BUILD_ROOT%{plugindir}/%{plugin}
cp -a nagios.cfg $RPM_BUILD_ROOT%{_sysconfdir}/%{plugin}.cfg

%clean
rm -rf $RPM_BUILD_ROOT

%post
if ! grep -q '^Cmnd_Alias MULTIPATH' /etc/sudoers; then
	cat >> /etc/sudoers <<-'EOF'
		User_Alias MULTIPATH=nagios
		Cmnd_Alias MULTIPATH=/sbin/multipath -l,/sbin/lsmod
		Defaults:MULTIPATH !syslog
		MULTIPATH ALL=(root) NOPASSWD: MULTIPATH
	EOF
fi

%postun
if [ "$1" = 0 ]; then
	%{__sed} -i -e '/MULTIPATH/d' /etc/sudoers
fi

%files
%defattr(644,root,root,755)
%config(noreplace) %verify(not md5 mtime size) %{_sysconfdir}/%{plugin}.cfg
%attr(755,root,root) %{plugindir}/%{plugin}
