use Test2::V0;
use exact -me;
use IPC::Run3 'run3';

chdir( me('..') );
run3( [ 'perl', '-c', 'build.pl' ], my \$in, my \$out, my \$err );
chomp($err);
is( $err, 'build.pl syntax OK', 'build compile check' );

done_testing;
