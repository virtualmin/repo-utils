#!/usr/bin/perl
# makemoduledeb.pl
# Create a Debian package for a webmin or usermin module or theme
use strict;
use warnings;
use POSIX;
use Term::ANSIColor qw(:constants);
use 5.010;

my $licence = "BSD";
my $email = "Jamie Cameron <jcameron\@webmin.com>";
my $target_dir = "/tmp";

my $tmp_dir = "/tmp/debian-module";
my $debian_dir = "$tmp_dir/DEBIAN";
my $control_file = "$debian_dir/control";
my $preinstall_file = "$debian_dir/preinst";
my $postinstall_file = "$debian_dir/postinst";
my $preuninstall_file = "$debian_dir/prerm";
my $postuninstall_file = "$debian_dir/postrm";
my $copyright_file = "$debian_dir/copyright";
my $changelog_file = "$debian_dir/changelog";
my $files_file = "$debian_dir/files";

#-r "/etc/debian_version" ||
#	die RED, "makemoduledeb.pl must be run on Debian", RESET;

# Parse command-line args
my ($force_theme, $url, $upstream, $debdepends, $no_prefix, $force_usermin,
    $release, $allow_overwrite, $final_mod, $dsc_file, $dir, $ver, @exclude);

while(@ARGV) {
	my $a = shift(@ARGV);
	if ($a eq "--force-theme") {
		$force_theme = 1;
		}
	elsif ($a eq "--licence" || $a eq "--license") {
		$licence = shift(@ARGV);
		}
	elsif ($a eq "--email") {
		$email = shift(@ARGV);
		}
	elsif ($a eq "--url") {
		$url = shift(@ARGV);
		}
	elsif ($a eq "--upstream") {
		$upstream = shift(@ARGV);
		}
	elsif ($a eq "--deb-depends") {
		$debdepends = 1;
		}
	elsif ($a eq "--no-prefix") {
		$no_prefix = 1;
		}
	elsif ($a eq "--usermin") {
		$force_usermin = 1;
		}
	elsif ($a eq "--target-dir") {
		$target_dir = shift(@ARGV);
		}
	elsif ($a eq "--dir") {
		$final_mod = shift(@ARGV);
		}
	elsif ($a eq "--release") {
		$release = shift(@ARGV);
		}
	elsif ($a eq "--allow-overwrite") {
		$allow_overwrite = 1;
		}
	elsif ($a eq "--dsc-file") {
		$dsc_file = shift(@ARGV);
		}
	elsif ($a eq "--exclude") {
		push(@exclude, shift(@ARGV));
		}
	elsif ($a =~ /^\-\-/) {
		print STDERR "Unknown option $a\n";
		exit(1);
		}
	else {
		if (!defined($dir)) {
			$dir = $a;
			}
		else {
			$ver = $a;
			}
		}
	}

# Validate args
if (!$dir) {
	print "usage: ", CYAN, "makemoduledeb.pl ";
	print YELLOW, "[--force-theme]\n";
	print "                        [--deb-depends]\n";
	print "                        [--no-prefix]\n";
	print "                        [--licence name]\n";
	print "                        [--email 'name <address>']\n";
	print "                        [--upstream 'name <address>']\n";
	print "                        [--provides provides]\n";
	print "                        [--usermin]\n";
	print "                        [--target-dir directory]\n";
	print "                        [--dir directory-in-package]\n";
	print "                        [--allow-overwrite]\n";
	print "                        [--dsc-file file.dsc]\n";
	print CYAN, "                        <module> ";
	print YELLOW, "[version]\n", RESET;
	exit(1);
	}
chop(my $par = `dirname $dir`);
chop(my $source_mod = `basename $dir`);
my $source_dir = "$par/$source_mod";
my $mod = $final_mod || $source_mod;
if ($mod eq "." || $mod eq "..") {
	die "directory must be an actual directory (module) name, not \"$mod\"";
	}

# Is this actually a module or theme directory?
my ($depends, $prefix, $desc, $product, $iver, $istheme, $post_config);
-d $source_dir || die RED, "$source_dir is not a directory", RESET;
my (%minfo, %tinfo);
if (read_file("$source_dir/module.info", \%minfo) && exists($minfo{'desc'})) {
	if (exists($minfo{'depends'})) {
		$depends = join(" ", map { s/\/[0-9\.]+//; $_ }
							 grep { !/^[0-9\.]+$/ }
				  		 split(/\s+/, $minfo{'depends'}));
	}
	if ($minfo{'usermin'} && (!$minfo{'webmin'} || $force_usermin)) {
		$prefix = "usermin-";
		$desc = "Usermin module $minfo{'desc'}";
		$product = "usermin";
		}
	else {
		$prefix = "webmin-";
		$desc = "Webmin module $minfo{'desc'}";
		$product = "webmin";
		}
	$iver = $minfo{'version'};
	$post_config = 1;
	}
elsif (read_file("$source_dir/theme.info", \%tinfo) && $tinfo{'desc'}) {
	if ($tinfo{'usermin'} && (!$tinfo{'usermin'} || $force_usermin)) {
		$prefix = "usermin-";
		$desc = "Usermin theme $tinfo{'desc'}";
		$product = "usermin";
		}
	else {
		$prefix = "webmin-";
		$desc = "Webmin theme $tinfo{'desc'}";
		$product = "webmin";
		}
	$iver = $tinfo{'version'};
	$istheme = 1;
	$post_config = 0;
	}
else {
	die "$source_dir does not appear to be a webmin module or theme";
	}
$prefix = "" if ($no_prefix);
my $usr_dir = "$tmp_dir/usr/share/$product";
my $ucproduct = ucfirst($product);
$upstream ||= $email;

# Create the base directories
system("rm -rf $tmp_dir");
mkdir($tmp_dir, 0755);
chmod(0755, $tmp_dir);
mkdir($debian_dir, 0755);
chmod(0755, $debian_dir);
system("mkdir -p $usr_dir");

# Copy the directory to a temp directory
system("cp -r -p -L $source_dir $usr_dir/$mod");
system("echo deb >$usr_dir/$mod/install-type");
system("cd $usr_dir && chmod -R og-w .");
if ($< == 0) {
        system("cd $usr_dir && chown -R root:bin .");
        }
system("find $usr_dir -name .git | xargs rm -rf");
system("find $usr_dir -name RELEASE | xargs rm -rf");
system("find $usr_dir -name RELEASE.sh | xargs rm -rf");
if (-r "$usr_dir/$mod/EXCLUDE") {
	system("cd $usr_dir/$mod && cat EXCLUDE | xargs rm -rf");
	system("rm -f $usr_dir/$mod/EXCLUDE");
	}
foreach my $e (@exclude) {
	system("find $usr_dir -name ".quotemeta($e)." | xargs rm -rf");
	}
my $out = `du -sk $tmp_dir`;
my $size = $out =~ /^\s*(\d+)/ ? $1 : undef;

# Set version in .info file to match command line, if given
if ($ver) {
	if ($minfo{'desc'}) {
		$minfo{'version'} = $ver;
		&write_file("$usr_dir/$mod/module.info", \%minfo);
		}
	elsif ($tinfo{'desc'}) {
		$tinfo{'version'} = $ver;
		&write_file("$usr_dir/$mod/theme.info", \%tinfo);
		}
	}
else {
	$ver ||= $iver;		# Use module.info version, or 1
	$ver ||= 1;
	}
$ver .= "-".$release if ($release);

# Fix up Perl paths
system("(find $usr_dir -name '*.cgi' ; find $usr_dir -name '*.pl') | perl -ne 'chop; open(F,\$_); \@l=<F>; close(F); \$l[0] = \"#\!/usr/bin/perl\$1\n\" if (\$l[0] =~ /#\!\\S*perl\\S*(.*)/); open(F,\">\$_\"); print F \@l; close(F)'");
system("(find $usr_dir -name '*.cgi' ; find $usr_dir -name '*.pl') | xargs chmod +x");

# Build list of dependencies on other Debian packages, for inclusion as a
# Requires: header
my @rdeps = ( "base", "perl", $product );
if ($debdepends && exists($minfo{'depends'})) {
	foreach my $d (split(/\s+/, $minfo{'depends'})) {
		my ($dwebmin, $dmod, $dver);
		if ($d =~ /^[0-9\.]+$/) {
			# Depends on a version of Webmin
			$dwebmin = $d;
			}
		elsif ($d =~ /^(\S+)\/([0-9\.]+)$/) {
			# Depends on some version of a module
			$dmod = $1;
			$dver = $2;
			}
		else {
			# Depends on any version of a module
			$dmod = $d;
			}

		# If the module is part of Webmin, we don't need to depend on it
		if ($dmod) {
			my %dinfo;
			read_file("$dmod/module.info", \%dinfo);
			next if ($dinfo{'longdesc'});
			}
		push(@rdeps, $dwebmin ? ("$product (>= $dwebmin)") :
			     $dver ? ("$prefix$dmod (>= $dver)") :
				     ($prefix.$dmod));
		}
	}
my $rdeps = join(", ", @rdeps);

# Create the control file
my $kbsize = int(($size-1) / 1024)+1;
open(my $CONTROL, ">", "$control_file");
print $CONTROL <<EOF;
Package: $prefix$mod
Version: $ver
Section: admin
Priority: optional
Architecture: all
Essential: no
Depends: $rdeps
Pre-Depends: bash, perl
Installed-Size: $kbsize
Maintainer: $email
Provides: $prefix$mod
Description: $desc
EOF
close($CONTROL);

# Create the copyright file
my $nowstr = strftime("%a, %d %b %Y %H:%M:%S %z", localtime(time()));
open(my $COPY, ">", "$copyright_file");
print $COPY "This package was debianized by $email on\n";
print $COPY "$nowstr.\n";
print $COPY "\n";
if ($url) {
	print $COPY "It was downloaded from: $url\n";
	print $COPY "\n";
	}
print $COPY "Upstream author: $upstream\n";
print $COPY "\n";
print $COPY "Copyright: $licence\n";
close($COPY);

# Read the module's CHANGELOG file
my $changes = { };
my $f = "$usr_dir/$mod/CHANGELOG";
if (-r $f) {
	# Read its change log file
	my $inversion;
	open(my $LOG, $f);
	while(<$LOG>) {
		s/\r|\n//g;
		if (/^----\s+Changes\s+since\s+(\S+)\s+----/) {
			$inversion = $1;
			}
		elsif ($inversion && /\S/) {
			push(@{$changes->{$inversion}}, $_);
			}
		}
	close($LOG);
	}

# Create the changelog file from actual changes
if (%$changes) {
	open(my $CHANGELOG, ">", "$changelog_file");
	my $forv;
	my $clver = $ver;
	$clver =~ s/\.[^0-9\.]*$//;
	foreach my $v (sort { $a <=> $b } (keys %$changes)) {
		if ($clver > $v && sprintf("%.2f0", $clver) == $v) {
			$forv = $clver;
			}
		else {
			$forv = sprintf("%.2f0", $v+0.01);
			}
		print $CHANGELOG "$prefix$mod ($forv) stable; urgency=low\n";
		print $CHANGELOG "\n";
		foreach my $c (@{$changes->{$v}}) {
			my @lines = wrap_lines($c, 65);
			print $CHANGELOG " * $lines[0]\n";
			foreach my $l (@lines[1 .. $#lines]) {
				print $CHANGELOG "   $l\n";
				}
			}
		print $CHANGELOG "\n";
		print $CHANGELOG "-- $email\n";
		print $CHANGELOG "\n";
		}
	close($CHANGELOG);
	}

$depends //= "";
$force_theme //= "";
$istheme //= "";

# Create the pre-install script, which checks if Webmin is installed
open(my $PREINSTALL, ">", "$preinstall_file");
no warnings "uninitialized";
print $PREINSTALL <<EOF;
#!/bin/sh
if [ ! -r /etc/$product/config -o ! -d /usr/share/$product ]; then
	echo "$ucproduct does not appear to be installed on your system."
	echo "This package cannot be installed unless the Debian version of $ucproduct"
	echo "is installed first."
	exit 1
fi
if [ "$depends" != "" -a "$debdepends" != 1 ]; then
	# Check if depended webmin/usermin modules are installed
	for d in $depends; do
		if [ ! -r /usr/share/$product/\$d/module.info ]; then
			echo "This $ucproduct module depends on the module \$d, which is"
			echo "not installed on your system."
			exit 1
		fi
	done
fi
# Check if this module is already installed
if [ -d /usr/share/$product/$mod -a "\$1" != "upgrade" -a "$allow_overwrite" != "1" ]; then
	echo "This $ucproduct module is already installed on your system."
	exit 1
fi
EOF
close($PREINSTALL);
system("chmod 755 $preinstall_file");

# Create the post-install script
open(my $POSTINSTALL, ">", "$postinstall_file");
print $POSTINSTALL <<EOF;
#!/bin/sh
if [ "$post_config" = "1" ]; then
	# Copy config file to /etc/webmin or /etc/usermin
	os_type=`grep "^os_type=" /etc/$product/config | sed -e 's/os_type=//g'`
	os_version=`grep "^os_version=" /etc/$product/config | sed -e 's/os_version=//g'`
	/usr/bin/perl /usr/share/$product/copyconfig.pl \$os_type \$os_version /usr/share/$product /etc/$product $mod

	# Update the ACL for the root user, or the first user in the ACL
	grep "^root:" /etc/$product/webmin.acl >/dev/null
	if [ "\$?" = "0" ]; then
		user=root
	else
		user=`head -1 /etc/$product/webmin.acl | cut -f 1 -d :`
	fi
	mods=`grep \$user: /etc/$product/webmin.acl | cut -f 2 -d :`
	echo \$mods | grep " $mod" >/dev/null
	if [ "\$?" != "0" ]; then
		grep -v ^\$user: /etc/$product/webmin.acl > /tmp/webmin.acl.tmp
		echo \$user: \$mods $mod > /etc/$product/webmin.acl
		cat /tmp/webmin.acl.tmp >> /etc/$product/webmin.acl
		rm -f /tmp/webmin.acl.tmp
	fi
fi
if [ "$force_theme" != "" -a "$istheme" = "1" ]; then
	# Activate this theme
	grep -v "^preroot=" /etc/$product/miniserv.conf >/etc/$product/miniserv.conf.tmp
	(cat /etc/$product/miniserv.conf.tmp ; echo preroot=$mod) > /etc/$product/miniserv.conf
	rm -f /etc/$product/miniserv.conf.tmp
	grep -v "^theme=" /etc/$product/config >/etc/$product/config.tmp
	(cat /etc/$product/config.tmp ; echo theme=$mod) > /etc/$product/config
	rm -f /etc/$product/config.tmp
	(/etc/$product/stop && /etc/$product/start) >/dev/null 2>&1
fi
rm -f /etc/$product/module.infos.cache
rm -f /var/$product/module.infos.cache

# Run post-install function
if [ "$product" = "webmin" ]; then
	cd /usr/share/$product
	WEBMIN_CONFIG=/etc/$product WEBMIN_VAR=/var/$product /usr/share/$product/run-postinstalls.pl $mod
fi

# Run post-install shell script
if [ -r "/usr/share/$product/$mod/postinstall.sh" ]; then
	cd /usr/share/$product
	WEBMIN_CONFIG=/etc/$product WEBMIN_VAR=/var/$product /usr/share/$product/$mod/postinstall.sh
fi
EOF
close($POSTINSTALL);
system("chmod 755 $postinstall_file");

# Create the pre-uninstall script
open(my $PREUNINSTALL, ">", "$preuninstall_file");
print $PREUNINSTALL <<EOF;
#!/bin/sh
# De-activate this theme, if in use and if we are not upgrading
if [ "$istheme" = "1" -a "\$1" != "upgrade" ]; then
	grep "^preroot=$mod" /etc/$product/miniserv.conf >/dev/null
	if [ "\$?" = "0" ]; then
		grep -v "^preroot=$mod" /etc/$product/miniserv.conf >/etc/$product/miniserv.conf.tmp
		(cat /etc/$product/miniserv.conf.tmp) > /etc/$product/miniserv.conf
		rm -f /etc/$product/miniserv.conf.tmp
		grep -v "^theme=$mod" /etc/$product/config >/etc/$product/config.tmp
		(cat /etc/$product/config.tmp) > /etc/$product/config
		rm -f /etc/$product/config.tmp
		(/etc/$product/stop && /etc/$product/start) >/dev/null 2>&1
	fi
fi
# Run the pre-uninstall script, if we are not upgrading
if [ "$product" = "webmin" -a "\$1" = "0" -a -r "/usr/share/$product/$mod/uninstall.pl" ]; then
	cd /usr/share/$product
	WEBMIN_CONFIG=/etc/$product WEBMIN_VAR=/var/$product /usr/share/$product/run-uninstalls.pl $mod
fi
/bin/true
EOF
close($PREUNINSTALL);
system("chmod 755 $preuninstall_file");

# Run the actual build command
system("fakeroot dpkg --build $tmp_dir $target_dir/${prefix}${mod}_${ver}_all.deb") &&
        die "dpkg failed";
print "Wrote $target_dir/${prefix}${mod}_${ver}_all.deb\n";

# Create the .dsc file, if requested
if ($dsc_file) {
	# Create the .diff file, which just contains the debian directory
	my $diff_file = $dsc_file;
	$diff_file =~ s/[^\/]+$//; $diff_file .= "$prefix$mod-$ver.diff";
	my $diff_orig_dir = "$tmp_dir/$prefix$mod-$ver-orig";
	my $diff_new_dir = "$tmp_dir/$prefix$mod-$ver";
	mkdir($diff_orig_dir, 0755);
	mkdir($diff_new_dir, 0755);
	system("cp -r $debian_dir $diff_new_dir");
	system("cd $tmp_dir && diff -r -N -u $prefix$mod-$ver-orig $prefix$mod-$ver >$diff_file");
	my $diffmd5 = `md5sum $diff_file`;
	$diffmd5 =~ s/\s+.*\n//g;
	my @diffst = stat($diff_file);

	# Create a tar file of the module directory
	my $tar_file = $dsc_file;
	$tar_file =~ s/[^\/]+$//; $tar_file .= "$prefix$mod-$ver.tar.gz";
	system("cd $par ; tar czf $tar_file $source_mod");
	my $md5 = `md5sum $tar_file`;
	$md5 =~ s/\s+.*\n//g;
	my @st = stat($tar_file);

	# Finally create the .dsc
	open(my $DSC, ">", "$dsc_file");
	print $DSC <<EOF;
Format: 1.0
Source: $prefix$mod
Version: $ver
Binary: $prefix$mod
Maintainer: $email
Architecture: all
Standards-Version: 3.6.1
Build-Depends-Indep: debhelper (>= 4.1.16), debconf (>= 0.5.00), perl
Uploaders: Jamie Cameron <jcameron\@webmin.com>
Files:
  $md5 $st[7] ${prefix}${mod}-$ver.tar.gz
  $diffmd5 $diffst[7] ${prefix}${mod}-${ver}.diff
EOF
	close($DSC);
	}

# Clean up
# XXX Dangerous! Fix me.
system("rm -rf $tmp_dir");

# read_file(file, &assoc, [&order], [lowercase])
# Fill an associative array with name=value pairs from a file
sub read_file
{
open(my $ARFILE, "<", "$_[0]") || return 0;
while(<$ARFILE>) {
	s/\r|\n//g;
        if (!/^#/ && /^([^=]+)=(.*)$/) {
		$_[1]->{$_[3] ? lc($1) : $1} = $2;
		push(@{$_[2]}, $1) if ($_[2]);
        	}
        }
close($ARFILE);
return 1;
}

# write_file(file, array)
# Write out the contents of an associative array as name=value lines
sub write_file
{
my (%old, @order);
&read_file($_[0], \%old, \@order);
open(ARFILE, ">$_[0]");
foreach my $k (@order) {
        print ARFILE $k,"=",$_[1]->{$k},"\n" if (exists($_[1]->{$k}));
	}
foreach my $k (keys %{$_[1]}) {
        print ARFILE $k,"=",$_[1]->{$k},"\n" if (!exists($old{$k}));
        }
close(ARFILE);
}

# wrap_lines(text, width)
# Given a multi-line string, return an array of lines wrapped to
# the given width
sub wrap_lines
{
my @rv;
my $w = $_[1];
my $rest;
foreach my $rest (split(/\n/, $_[0])) {
	if ($rest =~ /\S/) {
		while($rest =~ /^(.{1,$w}\S*)\s*([\0-\377]*)$/) {
			push(@rv, $1);
			$rest = $2;
			}
		}
	else {
		# Empty line .. keep as it is
		push(@rv, $rest);
		}
	}
return @rv;
}
