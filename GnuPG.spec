Summary: Perl interface to the Gnu Privacy Guard
Name: GnuPG
Version: 0.02
Release: 1i
Source: http://indev.insu.com/projects/GnuPG/%{name}-%{version}.tar.gz
Copyright: GPL
Group: Development/Libraries/Perl
Prefix: /usr
URL: http://indev.insu.com/projects/GnuPG/
BuildRoot: /var/tmp/%{name}-%{version}-root
BuildArchitectures: noarch
Requires: perl gnupg

%description
GnuPG is a perl interface to the GNU Privacy Guard. It uses the shared
memory coprocess interface that gpg provides for its wrappers. It
tries its best to map the interactive interface of the gpg to a more
programmatic model.

%prep
%setup -q
# Update all path to the perl interpreter
find -type f -exec sh -c 'if head -c 100 $0 | grep -q "^#!.*perl"; then \
		perl -p -i -e "s|^#!.*perl|#!/usr/bin/perl|g" $0; fi' {} \;

%build
perl Makefile.PL 
make OPTIMIZE="$RPM_OPT_FLAGS"
#make test

%install
rm -fr $RPM_BUILD_ROOT
eval `perl '-V:installarchlib'`
mkdir -p $RPM_BUILD_ROOT/$installarchlib
make 	PREFIX=$RPM_BUILD_ROOT/usr \
	INSTALLMAN1DIR=$RPM_BUILD_ROOT/usr/man/man1 \
   	INSTALLMAN3DIR=$RPM_BUILD_ROOT/`dirname $installarchlib`/man/man3 \
   	pure_install

# Fix packing list
for packlist in `find $RPM_BUILD_ROOT -name '.packlist'`; do
	mv $packlist $packlist.old
	sed -e "s|$RPM_BUILD_ROOT||g" < $packlist.old > $packlist
	rm -f $packlist.old
done

# Make a file list
find $RPM_BUILD_ROOT -type f -o -type l | \
	grep -v perllocal.pod | \
	sed -e "s|$RPM_BUILD_ROOT||g" > %{name}-file-list
perl -n -i -e 'print "%doc " if m!man/man|\.pod!; print; ' %{name}-file-list

%clean
rm -fr $RPM_BUILD_ROOT

%files -f %{name}-file-list
%defattr(-,root,root)
%doc README ChangeLog

%changelog
* Wed Sep 08 1999  Francis J. Lacoste <francis.lacoste@iNsu.COM> 
  [0.02-1i]
- Added gpgmailtunl and its man pages.
- Updated to version 0.02.

* Sun Sep 05 1999 Francis J. Lacoste <francis.lacoste@iNsu.COM>
  [0.01-1i]
- Packaged for iNs/linux


