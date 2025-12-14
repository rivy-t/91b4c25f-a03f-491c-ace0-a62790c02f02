mkdir seed
cp user-data seed/user-data
cp meta-data seed/meta-data
[ -f network-config ] && cp network-config seed/network-config

cloud-localds seed.iso user-data meta-data network-config

