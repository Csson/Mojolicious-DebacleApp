requires 'perl', '5.020000';

requires 'Mojolicious', '5.25';
requires 'Kavorka', '0.33';
requires 'String::Random', '0.23';

on test => sub {
    requires 'Test::More', '0.96';
};
