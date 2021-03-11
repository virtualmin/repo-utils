sub compare_version_numbers
{
my ($ver1, $ver2) = @_;
my @sp1 = split(/[\.\-\+\~\_]/, $ver1);
my @sp2 = split(/[\.\-\+\~\_]/, $ver2);
my $tmp;
for(my $i=0; $i<@sp1 || $i<@sp2; $i++) {
	my $v1 = $sp1[$i];
	my $v2 = $sp2[$i];
	my $comp;
	$v1 =~ s/^ubuntu//g;
	$v2 =~ s/^ubuntu//g;
	if ($v1 =~ /^\d+$/ && $v2 =~ /^\d+$/) {
		# Numeric only
		# ie. 5 vs 7
		$comp = $v1 <=> $v2;
		}
	elsif ($v1 =~ /^(\d+[^0-9]+)(\d+)$/ && ($tmp = $1) &&
	       $v2 =~ /^(\d+[^0-9]+)(\d+)$/ &&
	       $tmp eq $1) {
		# Numeric followed by a string followed by a number, where
		# the first two components are the same
		# ie. 4ubuntu8 vs 4ubuntu10
		$v1 =~ /^(\d+[^0-9]+)(\d+)$/;
		my $num1 = $2;
		$v2 =~ /^(\d+[^0-9]+)(\d+)$/;
		my $num2 = $2;
		$comp = $num1 <=> $num2;
		}
	elsif ($v1 =~ /^\d+\S*$/ && $v2 =~ /^\d+\S*$/) {
		# Numeric followed by string
		# ie. 6redhat vs 8redhat
		$v1 =~ /^(\d+)(\S*)$/;
		my ($v1n, $v1s) = ($1, $2);
		$v2 =~ /^(\d+)(\S*)$/;
		my ($v2n, $v2s) = ($1, $2);
		$comp = $v1n <=> $v2n;
		if (!$comp) {
			# X.rcN is always older than X
			if ($v1s =~ /^rc\d+$/i && $v2s =~ /^\d*$/) {
				$comp = -1;
				}
			elsif ($v1s =~ /^\d*$/ && $v2s =~ /^rc\d+$/i) {
				$comp = 1;
				}
			else {
				$comp = $v1s cmp $v2s;
				}
			}
		}
	elsif ($v1 =~ /^(\S+[^0-9]+)(\d+)$/ && ($tmp = $1) &&
	       $v2 =~ /^(\S+[^0-9]+)(\d+)$/ &&
	       $tmp eq $1) {
		# String followed by a number, where the strings are the same
		# ie. centos7 vs centos8
		$v1 =~ /^(\S+[^0-9]+)(\d+)$/;
		my $num1 = $2;
		$v2 =~ /^(\S+[^0-9]+)(\d+)$/;
		my $num2 = $2;
		$comp = $num1 <=> $num2;
		}
	elsif ($v1 =~ /^\d+$/ && $v2 !~ /^\d+$/) {
		# Numeric compared to non-numeric - numeric is always higher
		$comp = 1;
		}
	elsif ($v1 !~ /^\d+$/ && $v2 =~ /^\d+$/) {
		# Non-numeric compared to numeric - numeric is always higher
		$comp = -1;
		}
	else {
		# String compare only
		$comp = $v1 cmp $v2;
		}
	return $comp if ($comp);
	}
return 0;
}


1;
