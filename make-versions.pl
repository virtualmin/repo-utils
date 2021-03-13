#!/usr/bin/perl
# Create Webmin and Usermin versoin files
require "./repo-utils-funcs.pl";
if ($0 =~ /^(.*)\//) {
        chdir($1);
        }
opendir(DIR, ".");
foreach my $f (readdir(DIR)) {
        if ($f =~ /^(webmin|usermin)-([0-9\.]+)\.tar.gz$/) {
                $pkg = $1;
                $ver = $2;
		if (compare_version_numbers($ver, $maxver{$pkg}) == 1) {
                        # Found a new winner
                        $maxver{$pkg} = $ver;
                        }
                }
        }
closedir(DIR);
foreach my $pkg (keys %maxver) {
        print "Latest version for $pkg is $maxver{$pkg}\n";
        unlink("$pkg-current.tar.gz");
        symlink("$pkg-$maxver{$pkg}.tar.gz", "$pkg-current.tar.gz");
        open(VER, ">$pkg-version");
        print VER $maxver{$pkg},"\n";
        closedir(VER);
        }


