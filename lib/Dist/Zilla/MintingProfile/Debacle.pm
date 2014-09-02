package Dist::Zilla::MintingProfile::TheBest {
	use Moose;
	with 'Dist::Zilla::Role::MintingProfile::ShareDir';

	__PACKAGE__->meta->make_immutable;
}

1;