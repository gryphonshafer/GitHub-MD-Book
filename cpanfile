requires 'Cwd', '3.75';
requires 'Date::Format', '2.24';
requires 'Encode', '3.21';
requires 'Log::Log4perl', '1.57';
requires 'Mojolicious', '9.37';
requires 'Text::MultiMarkdown', '1.002';
requires 'WWW::Mechanize::Chrome', '0.73';
requires 'YAML::XS', '0.89';
requires 'exact', '1.25';
requires 'exact::cli', '1.07';
requires 'exact::me', '1.05';

on test => sub {
    requires 'IPC::Run3', '0.049';
    requires 'Test2::V0', '0.000163';
    requires 'Test::EOL', '2.02';
    requires 'Test::Mojibake', '1.3';
    requires 'Test::NoTabs', '2.02';
    requires 'Test::Portability::Files', '0.10';
    requires 'Text::Gitignore', '0.04';
};
