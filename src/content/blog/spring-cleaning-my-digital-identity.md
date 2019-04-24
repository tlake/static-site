---
title: "spring cleaning my digital identity"
date: 2019-04-19T09:19:09-07:00
tags: [
    'crypto',
    'keybase',
    'pgp',
    'gpg',
	'github',
]
toc: true
---

I'd been reading up about [`git-secret`](https://git-secret.io/) and realized that I didn't really grasp what a PGP key is or how to use one (or more).
I've had a [Keybase](https://keybase.io) account since 2011, and it's become a bit of a disjointed mess.
The addition and revocation of devices makes sense, since I've gone through a couple of phones since 2011.
However, my usage of PGP keys has been erratic.

You see, my nebulous grasp of PGP keys roughly equated them with SSH keys, and so I'd created and revoked a few of them.
Only recently have I come to understand that a PGP key has more to do with creating trust and verifying one's identity than with making secure connections.

PGP keys have UIDs attached to them, consisting of a full name, an email address, and an optional comment.
A PGP key is your identity; it should represent who you are on the internet.
You can attach multiple UIDs to a PGP key if they're all identities you want to associate together.
However, if you need to separate some parts of yourself, you should use a different key for each persona.

So unlike SSH keys and API tokens, maybe I _shouldn't_ treat PGP keys as if they were disposable and single-purpose.
Definitely they should be revoked if compromised, but otherwise they should stick around to build trust and prove that I'm _me._

There's more to say about PGP, but this post is about the process I went through to sanify my PGP key situation.
There are some links at the end.


# the start

My Keybase account contained two PGP keys.
One was the key I had created all the way back in 2011 when I created the account.
The other was a key I had made in order to verify my identity on GitHub.
Both keys have the same `Tanner Lake <tanner.lake@gmail.com>` UID attached.
I consider both of these identites to belong to the same digital persona, so there's no need for two different keys.

My laptop contained three PGP keys.
One of them was the GitHub one from above, and another I had recently generated in preparation for `git-secret` before I decided to learn more about PGP keys
A third was a workplace key, and I have no idea what the fourth was for.


# the goal

The goal is to consolidate down to just two identities; just two keys.

My workplace key will remain unchanged; I don't intend for that to be particularly long-lived, and I haven't had to use it for very much of anything, so its impact is minimal.

My personal key will contain two UIDs: my personal UID (`Tanner Lake <tanner.lake@gmail.com>`) and my Keybase UID (`keybase.io/tlake <tlake@keybase.io>`).
I also intend to separate out capabilities into subkeys.
The master key will only be able to certify, and I want three separate subkeys which each can do only one of signing, encrypting, and authenticating.
Furthermore, the master private key will exist _only_ on an offline, encrypted USB device; the private subkeys (as well as the public primary key and subkeys) will continue to live on my working machine.

The old personal key on Keybase will need to be cross-signed with the new one to maintain the web of trust, and then revoked and removed.

The old GitHub key will need to be removed from GitHub, Keybase, and my local GPG keyring, and I'll need to add my new personal public key to GitHub and sign my commits using the new signing key.

All keys that are not my new personal key and my workplace key will be deleted.


# the process

Sungo's post (linked below) at some point defers to Mike English's article (also linked below) to avoid regurgitation of commands.

I'm not that polished.

I'm writing to document my actions for myself, and I'm gonna list out every dang command I use.
If doing so is helpful to someone else, that's added value, but not the point.

- [take stock](#take-stock)
- [import the old key from keybase](#import-the-old-key-from-keybase)
- [generate a new master key](#generate-a-new-master-key)
- [cross-sign the old and new keys](#cross-sign-the-old-and-new-keys)
- [secure the new key](#secure-the-new-key)
- [obsolete the old key](#obsolete-the-old-key)
- [update keybase](#update-keybase)
- [update github](#update-github)
- [local cleanup](#local-cleanup)


## - take stock

But first, a note on reading the output from listing keys.
Consider the following labelled example:

```bash
pub   ENCRYPTION_METHOD/KEY_ID CREATION_DATE [ABILITIES] [EXPIRATION_DATE]
      KEY_FINGERPRINT
uid                 [TRUST_LEVEL] FULL_NAME <EMAIL> COMMENT
sub   ENCRYPTION_METHOD/KEY_ID CREATION_DATE [ABILITIES] [EXPIRATION_DATE]
```

The first column defines the type of entry.

- pub: a public key
- uid: a user ID
- sub: a public subkey
- sec: a secret key
- ssb: a secret subkey

Keys have abilities which define what they can do.
These abilities, noted within `[]` brackets, are as follows:

- C: Certify, or the ability to trust other keys.
- S: Sign, or the ability to state that the key created or approves of the signed data.
- E: Encrypt, or the ability to transform some information into an encoded form.
- A: Authenticate, or the ability to be used instead of a password.

Now, let's start by taking a look at what public keys my keyring has (passing the "`--keyid-format long`" flag prints out the key IDs as well):

```bash
$ gpg -k --keyid-format long

/Users/tanner/.gnupg/pubring.gpg
--------------------------------
pub   rsa4096/4D2701F13EDE5839 2018-04-02 [SC]
      6F291BE625AF2FF8E2E207514D2701F13EDE5839
uid                 [ultimate] Tanner Lake <tanner.lake@gmail.com>
sub   rsa4096/D437EEC879CD75B6 2018-04-02 [E]

pub   rsa4096/067D98D9C5F1ED56 2018-04-02 [SC] [expires: 2034-03-29]
      61732CF1F6E9D36AF37E2D6B067D98D9C5F1ED56
uid                 [ unknown] Tanner Lake <tanner.lake@gmail.com>
sub   rsa4096/E887D573CA2F0ABE 2018-04-02 [E] [expires: 2034-03-29]

pub   rsa4096/D9839DD152BBC30E 2018-05-16 [SC]
      AA86BF07B16AF7D371AFB129D9839DD152BBC30E
uid                 [ultimate] Tanner Lake <tlake@us.imshealth.com>
sub   rsa4096/D6F32208FCD344C8 2018-05-16 [E]
```

Let's also look at the private ones as well:

```bash
$ gpg -K --keyid-format long

/Users/tanner/.gnupg/pubring.gpg
--------------------------------
sec   rsa4096/4D2701F13EDE5839 2018-04-02 [SC]
      6F291BE625AF2FF8E2E207514D2701F13EDE5839
uid                 [ultimate] Tanner Lake <tanner.lake@gmail.com>
ssb   rsa4096/D437EEC879CD75B6 2018-04-02 [E]

sec   rsa4096/067D98D9C5F1ED56 2018-04-02 [SC] [expires: 2034-03-29]
      61732CF1F6E9D36AF37E2D6B067D98D9C5F1ED56
uid                 [ unknown] Tanner Lake <tanner.lake@gmail.com>
ssb   rsa4096/E887D573CA2F0ABE 2018-04-02 [E] [expires: 2034-03-29]

sec   rsa4096/D9839DD152BBC30E 2018-05-16 [SC]
      AA86BF07B16AF7D371AFB129D9839DD152BBC30E
uid                 [ultimate] Tanner Lake <tlake@us.imshealth.com>
ssb   rsa4096/D6F32208FCD344C8 2018-05-16 [E]
```

The first key is the one that I don't remember the reason for its creation, the second key is the one I had created to sign GitHub commits, and the third key is my workplace key.
None of these are the key that exists on Keybase, so I'll need to grab that next.


## - import the old key from keybase

Import the public key:

```bash
$ keybase pgp export | gpg --import
gpg: key 54B8519A0C437FEA: public key "Tanner Lake <tanner.lake@gmail.com>" imported
gpg: Total number processed: 1
gpg:               imported: 1
```

And import the private key:

```bash
$ keybase pgp export -s | gpg --import --allow-secret-key

gpg: key 54B8519A0C437FEA: "Tanner Lake <tanner.lake@gmail.com>" 1 new signature
gpg: key 54B8519A0C437FEA: secret key imported
gpg: Total number processed: 1
gpg:         new signatures: 1
gpg:       secret keys read: 1
gpg:   secret keys imported: 1
```

Now let's take a look at that new key, and confirm that both the public and private keys were imported:

```bash
$ gpg -k --keyid_format long 54B8519A0C437FEA

pub   rsa4096/54B8519A0C437FEA 2016-11-11 [SC]
      EAC03C08A76EA0F91ECD650254B8519A0C437FEA
uid                 [ unknown] Tanner Lake <tanner.lake@gmail.com>
uid                 [ unknown] keybase.io/tlake <tlake@keybase.io>
sub   rsa2048/6C444A94152F77FC 2016-11-11 [E] [expires: 2024-11-09]
sub   rsa2048/6227D98814ACA2F0 2016-11-11 [SA] [expires: 2024-11-09]
```

```bash
$ gpg -K --keyid_format long 54B8519A0C437FEA

sec   rsa4096/54B8519A0C437FEA 2016-11-11 [SC]
      EAC03C08A76EA0F91ECD650254B8519A0C437FEA
uid                 [ unknown] Tanner Lake <tanner.lake@gmail.com>
uid                 [ unknown] keybase.io/tlake <tlake@keybase.io>
ssb   rsa2048/6C444A94152F77FC 2016-11-11 [E] [expires: 2024-11-09]
ssb   rsa2048/6227D98814ACA2F0 2016-11-11 [SA] [expires: 2024-11-09]
```


## - generate a new master key

This `--full-gen-key` flag will enter me into an interactive prompt, and `--expert` exposes otherwise-hidden options.
I want to use the RSA algorithm and set my own capabilities, so that's the option I'll choose.

```bash
$ gpg --expert --full-gen-key

gpg (GnuPG) 2.2.13; Copyright (C) 2019 Free Software Foundation, Inc.
This is free software: you are free to change and redistribute it.
There is NO WARRANTY, to the extent permitted by law.

Please select what kind of key you want:
   (1) RSA and RSA (default)
   (2) DSA and Elgamal
   (3) DSA (sign only)
   (4) RSA (sign only)
   (7) DSA (set your own capabilities)
   (8) RSA (set your own capabilities)
   (9) ECC and ECC
  (10) ECC (sign only)
  (11) ECC (set your own capabilities)
  (13) Existing key
Your selection? 8
```

For this master key, I only want it to have certification abilities; the other actions will be assigned their own subkeys.

```bash
Possible actions for a RSA key: Sign Certify Encrypt Authenticate
Current allowed actions: Sign Certify Encrypt

   (S) Toggle the sign capability
   (E) Toggle the encrypt capability
   (A) Toggle the authenticate capability
   (Q) Finished

Your selection? s

Possible actions for a RSA key: Sign Certify Encrypt Authenticate
Current allowed actions: Certify Encrypt

   (S) Toggle the sign capability
   (E) Toggle the encrypt capability
   (A) Toggle the authenticate capability
   (Q) Finished

Your selection? e

Possible actions for a RSA key: Sign Certify Encrypt Authenticate
Current allowed actions: Certify

   (S) Toggle the sign capability
   (E) Toggle the encrypt capability
   (A) Toggle the authenticate capability
   (Q) Finished

Your selection? q
```

Set the keysize and expiration.

```bash
RSA keys may be between 1024 and 4096 bits long.
What keysize do you want? (2048) 4096
Requested keysize is 4096 bits
Please specify how long the key should be valid.
         0 = key does not expire
      <n>  = key expires in n days
      <n>w = key expires in n weeks
      <n>m = key expires in n months
      <n>y = key expires in n years
Key is valid for? (0) 10y
Key expires at Fri Apr 20 13:19:45 2029 PDT
Is this correct? (y/N) y
```

Supply a name, an email, and an optional comment, and then the key will be created.

```bash
GnuPG needs to construct a user ID to identify your key.

Real name: Tanner Lake
Email address: tanner.lake@gmail.com
Comment:
You selected this USER-ID:
    "Tanner Lake <tanner.lake@gmail.com>"

Change (N)ame, (C)omment, (E)mail or (O)kay/(Q)uit? O
We need to generate a lot of random bytes. It is a good idea to perform
some other action (type on the keyboard, move the mouse, utilize the
disks) during the prime generation; this gives the random number
generator a better chance to gain enough entropy.
gpg: key E3D3AB877ED44CED marked as ultimately trusted
gpg: revocation certificate stored as '/Users/tanner/.gnupg/openpgp-revocs.d/4069A137076EF02F8D4BEA3BE3D3AB877ED44CED.rev'
public and secret key created and signed.

pub   rsa4096 2019-04-23 [C] [expires: 2029-04-20]
      4069A137076EF02F8D4BEA3BE3D3AB877ED44CED
uid                      Tanner Lake <tanner.lake@gmail.com>
```

That's the master key created, but it's not yet complete.
I still want to add my keybase UID, and I still need to add the other subkeys.

Enter the `--edit-key` flag.
I could supply a key's UID, fingerprint, or key ID to target a key.
I'll use the key ID (E3D3AB877ED44CED), given in the output just above where the key was marked as ultimately trusted.

```bash
$ gpg --expert --edit-key E3D3AB877ED44CED

gpg (GnuPG) 2.2.13; Copyright (C) 2019 Free Software Foundation, Inc.
This is free software: you are free to change and redistribute it.
There is NO WARRANTY, to the extent permitted by law.

Secret key is available.

sec  rsa4096/E3D3AB877ED44CED
     created: 2019-04-23  expires: 2029-04-20  usage: C
     trust: ultimate      validity: ultimate
[ultimate] (1). Tanner Lake <tanner.lake@gmail.com>

gpg>
```

I'll start by adding and trusting my Keybase UID.

```bash
gpg> adduid
Real name: keybase.io/tlake
Email address: tlake@keybase.io
Comment:
You selected this USER-ID:
    "keybase.io/tlake <tlake@keybase.io>"

Change (N)ame, (C)omment, (E)mail or (O)kay/(Q)uit? o

sec  rsa4096/E3D3AB877ED44CED
     created: 2019-04-23  expires: 2029-04-20  usage: C
     trust: ultimate      validity: ultimate
[ultimate] (1)  Tanner Lake <tanner.lake@gmail.com>
[ unknown] (2). keybase.io/tlake <tlake@keybase.io>

gpg> uid 2

sec  rsa4096/E3D3AB877ED44CED
     created: 2019-04-23  expires: 2029-04-20  usage: C
     trust: ultimate      validity: ultimate
[ultimate] (1)  Tanner Lake <tanner.lake@gmail.com>
[ unknown] (2)* keybase.io/tlake <tlake@keybase.io>

gpg> trust
sec  rsa4096/E3D3AB877ED44CED
     created: 2019-04-23  expires: 2029-04-20  usage: C
     trust: ultimate      validity: ultimate
[ultimate] (1)  Tanner Lake <tanner.lake@gmail.com>
[ unknown] (2)* keybase.io/tlake <tlake@keybase.io>

Please decide how far you trust this user to correctly verify other users' keys
(by looking at passports, checking fingerprints from different sources, etc.)

  1 = I don't know or won't say
  2 = I do NOT trust
  3 = I trust marginally
  4 = I trust fully
  5 = I trust ultimately
  m = back to the main menu

Your decision? 5
Do you really want to set this key to ultimate trust? (y/N) y

sec  rsa4096/E3D3AB877ED44CED
     created: 2019-04-23  expires: 2029-04-20  usage: C
     trust: ultimate      validity: ultimate
[ultimate] (1)  Tanner Lake <tanner.lake@gmail.com>
[ unknown] (2)* keybase.io/tlake <tlake@keybase.io>

gpg> save
```

If I look at the key again, I'll see that both UIDs are trusted.

```bash
$ gpg -k --keyid-format long E3D3AB877ED44CED

pub   rsa4096/E3D3AB877ED44CED 2019-04-23 [C] [expires: 2029-04-20]
      4069A137076EF02F8D4BEA3BE3D3AB877ED44CED
uid                 [ultimate] keybase.io/tlake <tlake@keybase.io>
uid                 [ultimate] Tanner Lake <tanner.lake@gmail.com>
```

Next, I need to create three subkeys using the `addkey` gpg command.
When prompted for the kind of key I want, again I choose option 8, which is RSA + set capabilities.
Each subkey will have one of the actions associated with it, and will have an expiration of 5 years.

When all subkeys have been generated, exit with `save` again.

```bash
$ gpg --expert --edit-key E3D3AB877ED44CED

gpg (GnuPG) 2.2.13; Copyright (C) 2019 Free Software Foundation, Inc.
This is free software: you are free to change and redistribute it.
There is NO WARRANTY, to the extent permitted by law.

Secret key is available.

sec  rsa4096/E3D3AB877ED44CED
     created: 2019-04-23  expires: 2029-04-20  usage: C
     trust: ultimate      validity: ultimate
[ultimate] (1). keybase.io/tlake <tlake@keybase.io>
[ultimate] (2)  Tanner Lake <tanner.lake@gmail.com>

gpg> addkey

. . . . .

sec  rsa4096/E3D3AB877ED44CED
     created: 2019-04-23  expires: 2029-04-20  usage: C
     trust: ultimate      validity: ultimate
ssb  rsa4096/1601789A6957B1FF
     created: 2019-04-23  expires: 2024-04-21  usage: S
ssb  rsa4096/1010346AB8850E6D
     created: 2019-04-23  expires: 2024-04-21  usage: E
ssb  rsa4096/D3C910B1DE464464
     created: 2019-04-23  expires: 2024-04-21  usage: A
[ultimate] (1). keybase.io/tlake <tlake@keybase.io>
[ultimate] (2)  Tanner Lake <tanner.lake@gmail.com>

gpg> save
```


## - cross-sign the old and new keys

As noted by sungo, to maintain the web of trust I need to first sign the new key with the old key, and then sign the old key with the new key.
Note my key IDs:

- Old Key ID: `54B8519A0C437FEA`
- New Key ID: `E3D3AB877ED44CED`

```bash
$ gpg --default-key 54B8519A0C437FEA --sign-key E3D3AB877ED44CED

sec  rsa4096/E3D3AB877ED44CED
     created: 2019-04-23  expires: 2029-04-20  usage: C
     trust: ultimate      validity: ultimate
ssb  rsa4096/1601789A6957B1FF
     created: 2019-04-23  expires: 2024-04-21  usage: S
ssb  rsa4096/1010346AB8850E6D
     created: 2019-04-23  expires: 2024-04-21  usage: E
ssb  rsa4096/D3C910B1DE464464
     created: 2019-04-23  expires: 2024-04-21  usage: A
[ultimate] (1). keybase.io/tlake <tlake@keybase.io>
[ultimate] (2)  Tanner Lake <tanner.lake@gmail.com>

Really sign all user IDs? (y/N) y
gpg: using "54B8519A0C437FEA" as default secret key for signing

sec  rsa4096/E3D3AB877ED44CED
     created: 2019-04-23  expires: 2029-04-20  usage: C
     trust: ultimate      validity: ultimate
 Primary key fingerprint: 4069 A137 076E F02F 8D4B  EA3B E3D3 AB87 7ED4 4CED

     keybase.io/tlake <tlake@keybase.io>
     Tanner Lake <tanner.lake@gmail.com>

This key is due to expire on 2029-04-20.
Are you sure that you want to sign this key with your
key "Tanner Lake <tanner.lake@gmail.com>" (54B8519A0C437FEA)

Really sign? (y/N) y
```

```bash
$ gpg --default-key E3D3AB877ED44CED --sign-key 54B8519A0C437FEA

gpg: checking the trustdb
gpg: marginals needed: 3  completes needed: 1  trust model: pgp
gpg: depth: 0  valid:   3  signed:   0  trust: 0-, 0q, 0n, 0m, 0f, 3u
gpg: next trustdb check due at 2029-04-20
sec  rsa4096/54B8519A0C437FEA
     created: 2016-11-11  expires: never       usage: SC
     trust: unknown       validity: unknown
ssb  rsa2048/6C444A94152F77FC
     created: 2016-11-11  expires: 2024-11-09  usage: E
ssb  rsa2048/6227D98814ACA2F0
     created: 2016-11-11  expires: 2024-11-09  usage: SA
[ unknown] (1). Tanner Lake <tanner.lake@gmail.com>
[ unknown] (2)  keybase.io/tlake <tlake@keybase.io>

Really sign all user IDs? (y/N) y
gpg: using "E3D3AB877ED44CED" as default secret key for signing

sec  rsa4096/54B8519A0C437FEA
     created: 2016-11-11  expires: never       usage: SC
     trust: unknown       validity: unknown
 Primary key fingerprint: EAC0 3C08 A76E A0F9 1ECD  6502 54B8 519A 0C43 7FEA

     Tanner Lake <tanner.lake@gmail.com>
     keybase.io/tlake <tlake@keybase.io>

Are you sure that you want to sign this key with your
key "keybase.io/tlake <tlake@keybase.io>" (E3D3AB877ED44CED)

Really sign? (y/N) y
```

## - secure the new key

I've created an encrypted container on a USB device using VeraCrypt, and that's going to contain a backup of my personal key.
In addition, that encrypted containter will be the _only_ location of my private master key.

I'll start by creating a revocation certificate for the key in case it ever becomes compromised, and saving it to a file called `revocation_cert`.

```bash
$ gpg -a --gen-revoke E3D3AB877ED44CED > ./revocation_cert

sec  rsa4096/E3D3AB877ED44CED 2019-04-23 keybase.io/tlake <tlake@keybase.io>

Create a revocation certificate for this key? (y/N) y
Please select the reason for the revocation:
  0 = No reason specified
  1 = Key has been compromised
  2 = Key is superseded
  3 = Key is no longer used
  Q = Cancel
(Probably you want to select 1 here)
Your decision? 1
Enter an optional description; end it with an empty line:
>
Reason for revocation: Key has been compromised
(No description given)
Is this okay? (y/N) y
Revocation certificate created.

Please move it to a medium which you can hide away; if Mallory gets
access to this certificate he can use it to make your key unusable.
It is smart to print this certificate and store it away, just in case
your media become unreadable.  But have some caution:  The print system of
your machine might store the data and make it available to others!
```

I'm not sure who this Mallory character is, but fuck that person.

Now, I'll create the backups of the private and public keys.

```bash
$ gpg -a --export E3D3AB877ED44CED > ./public_key

$ gpg -a --export-secret-key E3D3AB877ED44CED > ./secret_key
```

Finally, I want to remove the master private key (the one with certification abilities) from my machine, so that the only copy of it lives on that USB.
That's a three step process:

#### 1. Export _just_ the master private subkeys to a file

```bash
$ gpg -a --export-secret-subkeys E3D3AB877ED44CED > ./secret_subkeys
```

#### 2. Delete _all_ the master private keys (primary and sub) from GPG

```bash
$ gpg --delete-secret-keys E3D3AB877ED44CED

gpg (GnuPG) 2.2.13; Copyright (C) 2019 Free Software Foundation, Inc.
This is free software: you are free to change and redistribute it.
There is NO WARRANTY, to the extent permitted by law.


sec  rsa4096/E3D3AB877ED44CED 2019-04-23 keybase.io/tlake <tlake@keybase.io>

Delete this key from the keyring? (y/N) y
This is a secret key! - really delete? (y/N) y
```

Confirmation:

```bash
$ gpg -k --keyid-format long E3D3AB877ED44CED

pub   rsa4096/E3D3AB877ED44CED 2019-04-23 [C] [expires: 2029-04-20]
      4069A137076EF02F8D4BEA3BE3D3AB877ED44CED
uid                 [ultimate] keybase.io/tlake <tlake@keybase.io>
uid                 [ultimate] Tanner Lake <tanner.lake@gmail.com>
sub   rsa4096/1601789A6957B1FF 2019-04-23 [S] [expires: 2024-04-21]
sub   rsa4096/1010346AB8850E6D 2019-04-23 [E] [expires: 2024-04-21]
sub   rsa4096/D3C910B1DE464464 2019-04-23 [A] [expires: 2024-04-21]


$ gpg -K --keyid-format long E3D3AB877ED44CED

gpg: error reading key: No secret key
```

#### 3. Import the subkey file

```bash
$ gpg --import ./secret_subkeys

gpg: key E3D3AB877ED44CED: "keybase.io/tlake <tlake@keybase.io>" not changed
gpg: To migrate 'secring.gpg', with each smartcard, run: gpg --card-status
gpg: key E3D3AB877ED44CED: secret key imported
gpg: Total number processed: 1
gpg:              unchanged: 1
gpg:       secret keys read: 1
gpg:   secret keys imported: 1
```

Confirm that the master private subkeys have been imported, but that the master private primary key has not (the `#` after `sec` indicates that the key is missing):

```bash
$ gpg -K --keyid-format long E3D3AB877ED44CED

sec#  rsa4096/E3D3AB877ED44CED 2019-04-23 [C] [expires: 2029-04-20]
      4069A137076EF02F8D4BEA3BE3D3AB877ED44CED
uid                 [ultimate] keybase.io/tlake <tlake@keybase.io>
uid                 [ultimate] Tanner Lake <tanner.lake@gmail.com>
ssb   rsa4096/1601789A6957B1FF 2019-04-23 [S] [expires: 2024-04-21]
ssb   rsa4096/1010346AB8850E6D 2019-04-23 [E] [expires: 2024-04-21]
ssb   rsa4096/D3C910B1DE464464 2019-04-23 [A] [expires: 2024-04-21]
```

I'll make sure those special files are encrypted in the USB container, then delete them from my machine.


## - obsolete the old key

I'll note the keyid that the old key has been obsoleted in favor of.

```bash
$ gpg -a --gen-revoke 54B8519A0C437FEA > ./revoke-oldkey

sec  rsa4096/54B8519A0C437FEA 2016-11-11 Tanner Lake <tanner.lake@gmail.com>

Create a revocation certificate for this key? (y/N) y
Please select the reason for the revocation:
  0 = No reason specified
  1 = Key has been compromised
  2 = Key is superseded
  3 = Key is no longer used
  Q = Cancel
(Probably you want to select 1 here)
Your decision? 2
Enter an optional description; end it with an empty line:
> superseded by keyid=E3D3AB877ED44CED
>
Reason for revocation: Key is superseded
superseded by keyid=E3D3AB877ED44CED
Is this okay? (y/N) y
Revocation certificate created.

Please move it to a medium which you can hide away; if Mallory gets
access to this certificate he can use it to make your key unusable.
It is smart to print this certificate and store it away, just in case
your media become unreadable.  But have some caution:  The print system of
your machine might store the data and make it available to others!
```

Import the revocation certificate to officially invalidate the old key.

```bash
$ gpg --import ./revoke-oldkey

gpg: key 54B8519A0C437FEA: "Tanner Lake <tanner.lake@gmail.com>" revocation certificate imported
gpg: Total number processed: 1
gpg:    new key revocations: 1
gpg: marginals needed: 3  completes needed: 1  trust model: pgp
gpg: depth: 0  valid:   3  signed:   0  trust: 0-, 0q, 0n, 0m, 0f, 3u
gpg: next trustdb check due at 2029-04-20
```

And confirm that it is so:

```bash
$ gpg -k --keyid-format long 54B8519A0C437FEA

pub   rsa4096/54B8519A0C437FEA 2016-11-11 [SC] [revoked: 2019-04-23]
      EAC03C08A76EA0F91ECD650254B8519A0C437FEA
uid                 [ revoked] Tanner Lake <tanner.lake@gmail.com>
uid                 [ revoked] keybase.io/tlake <tlake@keybase.io>
```

## - update keybase

I'll add the new key to Keybase:

```bash
$ keybase pgp select --multi E3D3AB877ED44CED

You are selecting a PGP key from your local GnuPG keychain, and
will publish a statement signed with this key to make it part of
your Keybase.io identity.

Note that GnuPG will prompt you to perform this signature.

You can also import the secret key to *local*, *encrypted* Keybase
keyring, enabling decryption and signing with the Keybase client.
To do that, use "--import" flag.

Learn more: keybase pgp help select

#    Algo    Key Id             Created   UserId
=    ====    ======             =======   ======
1    4096R   E3D3AB877ED44CED             keybase.io/tlake <tlake@keybase.io>, Tanner Lake <tanner.lake@gmail.com>
Choose a key: 1
▶ INFO Generated new PGP key:
▶ INFO   user: keybase.io/tlake <tlake@keybase.io>
▶ INFO   4096-bit RSA key, ID E3D3AB877ED44CED, created 2019-04-23
```

Then I'll use Keybase's UI to select the option to revoke the old key.
This opens a modal that contains the CLI command to run:

```bash
$ keybase pgp drop '0101c1f152a7c66c09ebec1121c4ee088b7422c8688ee875b1273e19dca8a7d066390a'

▶ INFO Revoking KIDs:
▶ INFO   0101c1f152a7c66c09ebec1121c4ee088b7422c8688ee875b1273e19dca8a7d066390a
```

## - update github

I removed all the GPG keys that were already associated with my account, then used GPG to export the ASCII-armor-formatted master public key to stdout.

```bash
$ gpg -a --export E3D3AB877ED44CED

# big public key output here
```

I copied that and pasted it into GitHub as a new GPG key, and then updated my `~/.gitconfig` file to sign commits using the key ID of the master key's signing subkey, which is the subkey with `[S]` in the list output.

```bash
$ gpg -K --keyid-format long E3D3AB877ED44CED

sec#  rsa4096/E3D3AB877ED44CED 2019-04-23 [C] [expires: 2029-04-20]
      4069A137076EF02F8D4BEA3BE3D3AB877ED44CED
uid                 [ultimate] keybase.io/tlake <tlake@keybase.io>
uid                 [ultimate] Tanner Lake <tanner.lake@gmail.com>
ssb   rsa4096/1601789A6957B1FF 2019-04-23 [S] [expires: 2024-04-21]
ssb   rsa4096/1010346AB8850E6D 2019-04-23 [E] [expires: 2024-04-21]
ssb   rsa4096/D3C910B1DE464464 2019-04-23 [A] [expires: 2024-04-21]
```

```bash
# ~/.gitconfig

[user]
    name = Tanner Lake
    email = tanner.lake@gmail.com
    signingkey = 1601789A6957B1FF
```

In hindsight, I probably could/should have left all my previous GPG keys on GitHub, which would have _not_ stripped all the "Verified" tags that had been previously made with other keys.
The lesson there, I guess, is that it's okay to keep revoked keys on GitHub just for history's sake; it's not like I'd be signing more commits with a key once it's been revoked.

Whatever.
A little scorched earth never hurt anyone.


# local cleanup

Now it's time to remove all the remaining artifacts and trash - namely, the unnecessary keys.
Secret keys need to be removed before the public keys can be removed.

```bash
$ gpg -K --keyid-format long
/Users/tanner/.gnupg/pubring.gpg
--------------------------------
sec   rsa4096/4D2701F13EDE5839 2018-04-02 [SC]
      6F291BE625AF2FF8E2E207514D2701F13EDE5839
uid                 [ultimate] Tanner Lake <tanner.lake@gmail.com>
ssb   rsa4096/D437EEC879CD75B6 2018-04-02 [E]

sec   rsa4096/067D98D9C5F1ED56 2018-04-02 [SC] [expires: 2034-03-29]
      61732CF1F6E9D36AF37E2D6B067D98D9C5F1ED56
uid                 [ unknown] Tanner Lake <tanner.lake@gmail.com>
ssb   rsa4096/E887D573CA2F0ABE 2018-04-02 [E] [expires: 2034-03-29]

sec   rsa4096/D9839DD152BBC30E 2018-05-16 [SC]
      AA86BF07B16AF7D371AFB129D9839DD152BBC30E
uid                 [ultimate] Tanner Lake <tlake@us.imshealth.com>
ssb   rsa4096/D6F32208FCD344C8 2018-05-16 [E]

sec   rsa4096/54B8519A0C437FEA 2016-11-11 [SC] [revoked: 2019-04-23]
      EAC03C08A76EA0F91ECD650254B8519A0C437FEA
uid                 [ revoked] Tanner Lake <tanner.lake@gmail.com>
uid                 [ revoked] keybase.io/tlake <tlake@keybase.io>

sec#  rsa4096/E3D3AB877ED44CED 2019-04-23 [C] [expires: 2029-04-20]
      4069A137076EF02F8D4BEA3BE3D3AB877ED44CED
uid                 [ultimate] keybase.io/tlake <tlake@keybase.io>
uid                 [ultimate] Tanner Lake <tanner.lake@gmail.com>
ssb   rsa4096/1601789A6957B1FF 2019-04-23 [S] [expires: 2024-04-21]
ssb   rsa4096/1010346AB8850E6D 2019-04-23 [E] [expires: 2024-04-21]
ssb   rsa4096/D3C910B1DE464464 2019-04-23 [A] [expires: 2024-04-21]
```

These are the key IDs of the three keys that need to be deleted:

- `4D2701F13EDE5839`
- `067D98D9C5F1ED56`
- `54B8519A0C437FEA`

```bash
$ for keyid in 4D2701F13EDE5839 067D98D9C5F1ED56 54B8519A0C437FEA ; \
	do gpg --delete-secret-key ${keyid} ; \
	gpg --delete-key ${keyid} ; \
done
```

```bash
$ gpg -k --keyid-format long

/Users/tanner/.gnupg/pubring.gpg
--------------------------------
pub   rsa4096/D9839DD152BBC30E 2018-05-16 [SC]
      AA86BF07B16AF7D371AFB129D9839DD152BBC30E
uid                 [ultimate] Tanner Lake <tlake@us.imshealth.com>
sub   rsa4096/D6F32208FCD344C8 2018-05-16 [E]

pub   rsa4096/E3D3AB877ED44CED 2019-04-23 [C] [expires: 2029-04-20]
      4069A137076EF02F8D4BEA3BE3D3AB877ED44CED
uid                 [ultimate] keybase.io/tlake <tlake@keybase.io>
uid                 [ultimate] Tanner Lake <tanner.lake@gmail.com>
sub   rsa4096/1601789A6957B1FF 2019-04-23 [S] [expires: 2024-04-21]
sub   rsa4096/1010346AB8850E6D 2019-04-23 [E] [expires: 2024-04-21]
sub   rsa4096/D3C910B1DE464464 2019-04-23 [A] [expires: 2024-04-21]


$ gpg -K --keyid-format long

/Users/tanner/.gnupg/pubring.gpg
--------------------------------
sec   rsa4096/D9839DD152BBC30E 2018-05-16 [SC]
      AA86BF07B16AF7D371AFB129D9839DD152BBC30E
uid                 [ultimate] Tanner Lake <tlake@us.imshealth.com>
ssb   rsa4096/D6F32208FCD344C8 2018-05-16 [E]

sec#  rsa4096/E3D3AB877ED44CED 2019-04-23 [C] [expires: 2029-04-20]
      4069A137076EF02F8D4BEA3BE3D3AB877ED44CED
uid                 [ultimate] keybase.io/tlake <tlake@keybase.io>
uid                 [ultimate] Tanner Lake <tanner.lake@gmail.com>
ssb   rsa4096/1601789A6957B1FF 2019-04-23 [S] [expires: 2024-04-21]
ssb   rsa4096/1010346AB8850E6D 2019-04-23 [E] [expires: 2024-04-21]
ssb   rsa4096/D3C910B1DE464464 2019-04-23 [A] [expires: 2024-04-21]
```


# and that's that!

I'm [tlake](https://keybase.io/tlake) on Keybase, which should now be wrangled into something sane.
It bothers me that my Keybase graph and history looks messy af with all these additions and revocations, but I guess pobody's nerfect, right?
Life's about the journey or whatever.


# helpful resources

These first are the two that really helped me the most with understanding what I was doing and how the moving parts of keys and subkeys work together (fun fact, the second link is also linked to in the first link):

- [a detailed but also top-level guide by sungo](https://sungo.wtf/2016/11/23/gpg-strong-keys-rotation-and-keybase.html)
- [a step-by-step how-to by Mike English](https://spin.atomicobject.com/2013/11/24/secure-gpg-keys-guide/)

The following links were still helpful, and although I came across them before the two above, they made better sense to me only after I'd read through the first two:

- [PGP security basics by Mark McDonnell](https://www.integralist.co.uk/posts/security-basics/index.html)
- [Github GPG + Keybase PGP by Ahmad Nassri](https://www.ahmadnassri.com/blog/github-gpg-keybase-pgp/index.html)
- [Keybase and GPG by Scott Lowe](https://blog.scottlowe.org/2017/09/06/using-keybase-gpg-macos/)
- [PGP key management on Stack Exchange](https://security.stackexchange.com/questions/29851/how-many-openpgp-keys-should-i-make)
