require 'yaml'
require 'json'

# Generate the missing zixflow.podspec.json
system("pod ipc spec .symlinks/plugins/zixflow/ios/zixflow.podspec > 'Pods/Local Podspecs/zixflow.podspec.json'")

# Now run pod install with --no-repo-update to skip the lockfile generation that's failing
exec("pod install --no-repo-update 2>&1 || true")
