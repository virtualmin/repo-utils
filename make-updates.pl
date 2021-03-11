#!/usr/bin/perl
# Creates an updates.txt file based on existing module files
require "./repo-utils-funcs.pl";
@dirs = ( "." );

# Find all available files
foreach $dir (@dirs) {
    opendir(DIR, $dir);
    foreach $f (readdir(DIR)) {
        next if ($f !~ /^([a-z\-]+)\-([0-9[^\.]+)\.(wbm|wbt)(\.gz)?$/);
        $mod = $1;
        $ver = $2;
        next if ($1 eq "virtualmin-nuvola");    # broken
        $ver =~ s/\-//g;
        $path = "$dir/$f";
        $path =~ s/^.*public_html//g;
        if (compare_version_numbers($ver, $bestver{$mod}) == 1) {
            $bestver{$mod} = $ver;
            $bestfile{$mod} = $path;
            }
        }
    closedir(DIR);
    }

# Print them out
foreach $mod ('virtual-server',
              (grep { $_ ne 'virtual-server' } (keys %bestfile))) {
    print join("\t", $mod, $bestver{$mod}, $bestfile{$mod}, 0,
                     "Latest version"),"\n";
    }

