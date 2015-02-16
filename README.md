## :mag_right: :hatched_chick: :page_with_curl: Google Scholar Alerts Twitter bot :page_with_curl: :hatched_chick: :mag_right:

Google Scholar lacks an API, but unlike PubMed **links directly to papers**. Often the stream of a Pubmed-sourced bot is filled with papers not deposited with direct links. *Occasionally* they will have a DOI, but Medline's indexing of these is inconsistent (the XML for articles themselves can be pretty inconsistent as I found out on [a previous excursion under Pubmed's bonnet](https://github.com/lmmx/watir-paper-scanner)).

Even when a paper is deposited with this identifier, the DOI minting process means it's not guaranteed that the link will work straight away - I myself have felt (and regularly see other scientists online expressing the same) frustration at having the basic line of scientific enquiry rudely interrupted by technical issues. Preprints are another consideration.

[![](https://pbs.twimg.com/media/Bd3Hj2GCIAABX-E.jpg)](http://arxiv.org/year/q-bio/13) <small>*[via](https://twitter.com/nextgenseek/status/422713358668668929)*</small>

> Preprints are undeniably [coming into the fold of bioscience research](https://www.youtube.com/watch?v=G1ffCDBPiOA), a practice originating in the physics/mathematical sciences that [crept in through common ground](https://twitter.com/leonidkruglyak/status/335422823025741826) at arXiv's [q-bio](http://arxiv.org/archive/q-bio) section. There are various dedicated sites/accounts monitoring particular subfields (e.g. [Haldane's sieve](haldanessieve.org)/@[haldanessieve](https://twitter.com/haldanessieve) for population/evolutionary genetics).
>
> Google Scholar indexes all fields, and in my own experience this leads to casual interdisciplinary reading in a way not possible from Pubmed's purely biomedical library - a facet of research which the [*BBSRC*, *MRC* and the *Society of Biology* feel is lacking amongst bioscientists](http://www.bbsrc.ac.uk/news/people-skills-training/2015/150204-n-report-vulnerable-research-skills-capabilities.aspx).

### Creating a feed of interest through Google Scholar

* Google Scholar Alerts can provide up to 20 results in an e-mail, and posting/archiving these somewhere other than a busy inbox makes new research more accessible
* Gmail for instance has various APIs and libraries, including an [official Python 2.6-2.7 package](https://developers.google.com/api-client-library/python/apis/gmail/v1) and [`gmailr`](https://github.com/jimhester/gmailr) for R
* Twitter likewise has [`python-twitter`](https://github.com/bear/python-twitter) and [`twitteR`](https://github.com/geoffjentry/twitteR)

This script checks for Google Scholar Alerts in a Gmail account, parses through the message for paper titles and links, and sends the list of new articles through to Twitter

* this could perhaps be automated with a cron job like Lynn Root used for her [*IfMeetThenTweet*](https://github.com/econchick/IfMeetThenTweet/) IFTTT alternative
* it could also perhaps be hosted on a free micro instance of Amazon Web Services EC2 (but I've not tried yet) *etc.*
* sending the papers to [Buffer](https://bufferapp.com/guides) doesn't make much sense since it seems to be at most 1 email a day, though perhaps other queries may vary

### Installation and usage

For a walkthrough on installation see the [Wiki homepage](https://github.com/lmmx/scholaRdaemon/wiki). Briefly:

* Install gmailr and twitteR, set up apps on [Google Dev console](https://developers.google.com/console/) and likewise for [Twitter's](https://apps.twitter.com/)
* Authorise gmailr (`gmail_auth`) with the JSON obtained by setting up an app
* Run `Rscript run_daemon` with `--help` to show available flags and bots.
     * Bots can be passed as arguments to `run_daemon` indicating which of the available account configurations to use, default behaviour being to check and tweet for all sequentially if unspecified.
     * These arguments are specified under `config/bot_registry.json`, where they are stored alongside the corresponding sub-directories to retrieve authentication information from. See the [Wiki](https://github.com/lmmx/scholaRdaemon/wiki/Running-multiple-bots) for more info.

### Automation

Dave Tang seems to have [beaten me to the idea of using R for a paper bot](http://davetang.org/muse/2015/01/31/transcriptome-feed-using-r/) by just a couple of weeks - he has a working example of a cron script, timed for Pubmed's release, as he worked with eUtils (i.e. Pubmed, like all the other existing bots in Casey Bergman's list, with the exception of [eQTLpapers](https://twitter.com/eQTL_papers) which has Scholar Alerts added manually by [Sarah Brown](https://twitter.com/sarahfbrooks)).

```cron
crontab -l
#minute hour dom month dow user cmd
0 15-23 * * * cd /Users/davetang/Dropbox/transcriptomes && ./feed.R &> /dev/null
```

Cron automation makes sense for daily MEDLINE (PubMed) updates, but not for emails - IFTTT-like 'triggering' would be ideal, and can be achieved with custom 'events' through Amazon Lambda [free tier], reacting to changes in AWS S3 file storage, which [may be modified](https://github.com/jb55/s3-blob-store) with [`dat`](http://dat-data.com/)` pull --live`.

* Wiki: [Proposed workflow with AWS and dat](https://github.com/lmmx/scholaRdaemon/wiki/Draft-workflow-with-AWS-and-dat)