requires 'Cwd', '3.75';
requires 'Date::Format', '2.24';
requires 'Encode', '3.17';
requires 'IPC::Run', '20200505.0';
requires 'Mojolicious', '9.25';
requires 'Text::MultiMarkdown', '1.000035';
requires 'YAML::XS', '0.83';
requires 'exact', '1.19';
requires 'exact::cli', '1.06';
requires 'exact::me', '1.04';

on test => sub {
    requires 'Test2::V0';
    requires 'Test::EOL';
    requires 'Test::Mojibake';
    requires 'Test::NoTabs';
    requires 'Test::Portability::Files';
    requires 'Text::Gitignore';
};
