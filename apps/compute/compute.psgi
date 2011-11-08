use strict;
use warnings;

use compute;

my $app = compute->apply_default_middlewares(compute->psgi_app);
$app;

