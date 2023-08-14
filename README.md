<!-- 
This README describes the package. If you publish this package to pub.dev,
this README's contents appear on the landing page for your package.

For information about how to write a good package README, see the guide for
[writing package pages](https://dart.dev/guides/libraries/writing-package-pages). 

For general information about developing packages, see the Dart guide for
[creating packages](https://dart.dev/guides/libraries/create-library-packages)
and the Flutter guide for
[developing packages and plugins](https://flutter.dev/developing-packages). 
-->

TODO: Put a short description of the package here that helps potential users
know whether this package might be useful for them.

## Features

TODO: List what your package can do. Maybe include images, gifs, or videos.

## Getting started

TODO: List prerequisites and provide or point to information on how to
start using the package.

## Usage

TODO: Include short and useful examples for package users. Add longer examples
to `/example` folder. 

```dart
const like = 'sample';
```

## Additional information

TODO: Tell users more about the package: where to find more information, how to 
contribute to the package, how to file issues, what response they can expect 
from the package authors, and more.

## SSMDC.v1

Group chats are a critical part of chatting, without them you can't call something
fully featured. Sadly.
For this reason p3p implements SSMDC (which stands for Single Server Multiple
Destinations Chat).

How does it work? On the client side of things there is parsing of extra fields from
messages involved to show the user that this chat is in fact a group.
But from the protocol client side it is just a normal chat - the same as one to one
chatroom - thank to this it is extremely easy to implement new clients / bots - you
don't need to care about supporting groups if you don't want to - and they will just
work (I'm talking to you XMPP).

Of course there is a way to distinguish between a group and private chat but this is
out of the scope for this readme.

B.. B.. But decentralization! Decentralized chats will come to p3pch4t - and it will
happen as soon as
 - The UI/UX is polished
 - **Actual** p2p will be supported out of the box - no relay magic.
 - All other chat features will be done.
However - I personally don't think that users will want p2p chats because they will
be (at least slightly) less advanced as the SSMDC chats - due to the nature of how
p2p networks work, decentralized group chats will feel less complete than the
federated one. 

p.s. by users here I mean the 99.5% of users, I know that there is a market for p2p
stuff. And I want't to address that market to... but priorities first.