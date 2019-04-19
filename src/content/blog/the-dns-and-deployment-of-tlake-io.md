---
title: "the dns and deployment of tlake.io"
date: 2019-04-18T09:19:09-07:00
---

![parked on the bun](/images/parked-on-the-bun.png)

[Porkbun](https://porkbun.com) is my new favorite domain registrar and had the best deals on .io domains that I could find, but I wanted to use [DNSimple](https://dnsimple.com) to manage my DNS settings.
DNSimple offers a robust API and a [Terraform provider](https://www.terraform.io/docs/providers/), which is very appealing to my infrastructure-as-code aspirations.
Luckily, it's pretty easy to get the best of both worlds:

- Through Porkbun, replace the domain's default nameservers with DNSimple's nameservers.

- Import the domain through DNSimple and _bam!_ now you can use their rad API to manage the domain, which you purchased somewhere else.

(Full disclosure: use of DNSimple's services _does_ require a subscription fee.)

Now, this is just a static site generated through [Hugo](https://gohugo.io/) and made pretty by the [Ananke](https://themes.gohugo.io/gohugo-theme-ananke/) theme.
It's deployed to a `docs/` directory on the [project repository](https://github.com/tlake/static-site)'s `master` branch, and uses the custom domain `tlake.io` instead of GitHub's default `tlake.github.io`.
It took a bit of doing to make GitHub happy, and this is the point of this post.

GitHub's got good documentation around [using a custom domain](https://help.github.com/en/articles/using-a-custom-domain-with-github-pages) with GitHub Pages.
In my case, I was looking to set up an apex domain (`tlake.io`, instead of something like `www.tlake.io`) as noted [here](https://help.github.com/en/articles/setting-up-an-apex-domain).
DNSimple does indeed allow me to configure `ALIAS` records, so I did.

![DNSimple records: ALIAS tlake.io -> tlake.github.io](/images/dnsimple-alias-record.png)

I built and deployed the site, updated the custom domain to `tlake.io` in the repo's settings, and gave the record some time to propagate.
Navigating to `tlake.io` displayed the homepage!
It was working!

Then I looked in the repo's settings again.

![GitHub error message: Domain's DNS record could not be retrieved.](/images/github-dns-error.png)

But... but the site's working.
I can navigate to it.
Other people can navigate to it.
What's GitHub's problem with it?

I did some **`dig`**ging (FUNNY JOKE) to see if `tlake.io` and `tlake.github.io` were resolving in the same way.

```bash
for d in tlake.io tlake.github.io ; do dig $d +noall +answer ; done

; <<>> DiG 9.8.3-P1 <<>> tlake.io +noall +answer
;; global options: +cmd
tlake.io.               2829    IN      A       185.199.110.153
tlake.io.               2829    IN      A       185.199.111.153
tlake.io.               2829    IN      A       185.199.109.153
tlake.io.               2829    IN      A       185.199.108.153

; <<>> DiG 9.8.3-P1 <<>> tlake.github.io +noall +answer
;; global options: +cmd
tlake.github.io.        2976    IN      A       185.199.109.153
tlake.github.io.        2976    IN      A       185.199.108.153
tlake.github.io.        2976    IN      A       185.199.111.153
tlake.github.io.        2976    IN      A       185.199.110.153
```

They were.

So what gives?

Well, after a couple hours of experimenting with DNS settings, I discovered a configuration that seemed to satisfy GitHub: adding a `CNAME` record that pointed `www.tlake.io` to `tlake.io`.
This combined with the previous `ALIAS` record convinced GitHub to stop complaining.

![DNSimple records: ALIAS tlake.io -> tlake.github.io, CNAME www.tlake.io -> tlake.io](/images/dnsimple-alias-cname-records.png)

![GitHub happy status](/images/github-happy-status.png)

And that's about it!
It's not particularly difficult, but it's a tiny thing that was overlooked in the documentation, and my Google Fu didn't turn up the answer, so here we are.
