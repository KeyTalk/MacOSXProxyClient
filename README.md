# MacOSXProxyClient

The KeyTalk Mac Proxy client project.

## Development
Fork Keytalk Mac Proxy client upstream source repository to your own personal repository. Copy the URL for Keytalk Mac Proxy client from your personal github repo (you will need it for the git clone command below).

```bash
$ mkdir -p $GOPATH/src/github.com/KeyTalk/MacOSXProxyClient
$ cd $GOPATH/src/github.com/KeyTalk/MacOSXProxyClient
$ git clone <paste saved URL for personal forked repo>
$ cd MacOSXProxyClient
```

Keytalk uses Cocoapods for dependencies, to get started, install CocoaPods and in the main project directory run:

```bash
$ pod install
```

Note that you must have a github account and a public key registered with github so that CocoaPods can pull down a github-hosted dependency.

Now you can open the xcode workspace file.
