%define		_plugin	check_multipath
Summary:	Nagios plugin to check the state of Linux device mapper multipath devices.
Name:		nagios-plugin-%{_plugin}
Version:	1.0
Release:	0.1
License:	GPL v2
Group:		Networking
Source0:	%{name}.sh
URL:		http://tinyurl.com/2aunjl
Requires:	nagios-core
Requires:	sudo
BuildArch:	noarch
BuildRoot:	%{tmpdir}/%{name}-%{version}-root-%(id -u -n)

%define		_plugindir	%{_prefix}/lib/nagios/plugins
%define		_sysconfdir	/etc/nagios/plugins

%description
Nagios plugin to check the state of Linux device mapper multipath devices.

%prep
%setup -qcT
install %{SOURCE0} %{_plugin}

cat > nagios.cfg <<'EOF'
# Usage:
# %{_plugin}
define command {
	command_name    %{_plugin}
	command_line    %{_plugindir}/%{_plugin}
}
EOF

%install
rm -rf $RPM_BUILD_ROOT
install -d $RPM_BUILD_ROOT{%{_sysconfdir},%{_plugindir}}
install %{_plugin} $RPM_BUILD_ROOT%{_plugindir}/%{_plugin}
cp -a nagios.cfg $RPM_BUILD_ROOT%{_sysconfdir}/%{_plugin}.cfg

%clean
rm -rf $RPM_BUILD_ROOT

%files
%defattr(644,root,root,755)
%config(noreplace) %verify(not md5 mtime size) %{_sysconfdir}/%{_plugin}.cfg
%attr(755,root,root) %{_plugindir}/%{_plugin}
