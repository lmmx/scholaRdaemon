# Google Scholar Alerts Twitter bot

Google Scholar lacks an API, but unlike PubMed **links directly to papers**. Often the stream of a Pubmed-sourced bot is filled with papers not deposited with direct links. *Occasionally* they will have a DOI, but Medline's indexing of these is inconsistent (the XML for articles themselves can be pretty inconsistent as I found out on [a previous excursion under Pubmed's bonnet](https://github.com/lmmx/watir-paper-scanner)).

Even when a paper is deposited with this identifier, the DOI minting process means it's not guaranteed that the link will work - I myself have felt, and have seen expressed by other scientists online the same frustration at having a line of enquiry rudely interrupted by technical issues.

Preprints are [coming into the fold of bioscience research](https://www.youtube.com/watch?v=G1ffCDBPiOA), with the practice of physics/mathematical sciences creeping in through the [common ground](https://twitter.com/leonidkruglyak/status/335422823025741826) of quantitative biology on arXiv.

[![](https://pbs.twimg.com/media/Bd3Hj2GCIAABX-E.jpg)](http://arxiv.org/year/q-bio/13) <small>*[via](https://twitter.com/nextgenseek/status/422713358668668929)*</small>

There are various dedicated sites/accounts monitoring particular subfields (e.g. [Haldane's sieve](haldanessieve.org)/@[haldanessieve](https://twitter.com/haldanessieve) for population/evolutionary genetics).

Google Scholar welcomes preprints from all fields, and in my own experience this leads to casual interdisciplinary reading: a facet of research which the [*BBSRC*, *MRC* and the *Society of Biology* feel is lacking amongst bioscientists](http://www.bbsrc.ac.uk/news/people-skills-training/2015/150204-n-report-vulnerable-research-skills-capabilities.aspx).

### Creating a feed of interest through Google Scholar

* Google Scholar Alerts can provide up to 20 results in an e-mail
* Gmail for instance (other e-mail providers are available!) has various accessible APIs - an [official package for Python 2.6-2.7](https://developers.google.com/api-client-library/python/apis/gmail/v1) and [`gmailr`](https://github.com/jimhester/gmailr) for R (a wrapper on the Python API)
* Twitter likewise has [`python-twitter`](https://github.com/bear/python-twitter) and [`twitteR`](https://github.com/geoffjentry/twitteR)

So, in theory you'd just need a Google Scholar Alert coming into a Gmail account, and either locally or on EC2 *etc.*:

* a Gmail checker (perhaps automated with a cron job like Lynn Root used for her [*IfMeetThenTweet*](https://github.com/econchick/IfMeetThenTweet/) IFTTT alternative)
* a quick parse through the message for paper titles and links
* send the list of new articles through to Twitter ([Buffer](https://bufferapp.com/guides)ing if so desired)

### 1: Gmail checker

> <small>At time of writing, there's an unresolved issue with [`gmailr`'s email sending ability](https://github.com/jimhester/gmailr/issues/11), but that's not of interest so I'll try R first.</small>

```r
install.packages('gmailr')
library('gmailr')
```

To access your mail, even for personal use, first register a new project at https://cloud.google.com/console#/project

![](Images/Img1GoogleDevConsoleNewProject.png)

After a short wait you can switch the Gmail API on from the sidebar under *API*, then `Create new client ID` under *Credentials*.

![](Images/Img2GoogleDevConsoleAPI.png)

While Twitter is accessed through the web, the script will be locally hosted (for now at least), so choose the option *Installed application*:

![](Images/Img3GoogleDevConsoleClientID.png)

...select your email and name the 'application'

![](Images/Img4GoogleDevConsoleConsent.png)

...go with the defaults, and JSON is ready to download

![](Images/Img5GoogleDevConsoleJSON.png)

This downloaded JSON serves as input to the `gmail_auth()` function, which I renamed `gmail_authfile.json` and added to my working directory.

![](Images/Img6GoogleDevConsoleTopSecret.png)

```r
gmail_auth('gmail_authfile.json')
```

<pre>Use a local file to cache OAuth access credentials between R sessions?
1: Yes
2: No

Selection: 1

Adding .httr-oauth to .gitignore
httpuv not installed, defaulting to out-of-band authentication
Please point your browser to the following url: 

  https://accounts.google.com/o/oauth2/auth?client_id=...apps.googleusercontent.com&scope=https%3A%2F%2Fwww.googleapis.com%2Fauth%2Fgmail.readonly&redirect_uri=urn%3Aietf%3Awg%3Aoauth%3A2.0%3Aoob&response_type=code

Enter authorization code:</pre>

Go ahead and add `*.json` to the `.gitignore` if you're versioning this, authorise the ability to read email, and enter the code provided.

The `gmailr` package deals with message IDs and thread IDs, while to read an email would need access to the content (rather than this 'metadata' accession ID). The package vignette only documents the outbound side of things, but the README highlights the `messages()` search function, and a glance over the [source code](https://github.com/jimhester/gmailr/blob/master/R/message.R) shows you retrieve an individual message content with `message('<message ID>')`.

```r
scholar.alerts <- messages('Scholar Alert')
# the message IDs are stored in a 'gmail_messages' class - a list
# num.msgs <- scholar.alerts[[1]][['resultSizeEstimate']]
msg.list <- scholar.alerts[[1]][['messages']]
```

Each 'message' in this structure is listed alongside its thread ID, and a message is retrieved with format *full*, *minimal*, or *raw*. For the purposes of grabbing the links to new articles we only need raw, *e.g.* for the most recent Scholar Alert in my inbox:

```r
eg.msg.id <- msg.list[[1]][['id']]
eg.msg.resp.raw <- message(eg.msg.id, format = "raw")
eg.msg.resp.raw.data <- eg.msg.resp.raw$raw

eg.msg.resp.full <- message(eg.msg.id, format = "full")
eg.msg.resp.full.data <- eg.msg.resp.full$payload$body$data
```

`eg.msg.resp.raw.data` and `eg.msg.resp.full.data` contains a comparable HTML 'payload', but the raw format stores it in [RFC 2822](https://tools.ietf.org/html/rfc2822) format whereas full uses JSON serialisation. 

> In *raw* format, message content has a maximum line length of 78 ([*RFC 2822 §2.1.1*](https://tools.ietf.org/html/rfc2822#section-2.1.1)) and needs to be stripped of `=\r\n` line breaks that crop up at around this frequency and the message content plucked out:
>
> ```r
# NB this throws away all of the message content ahead of the HTML
# (which is provided by the API in other discrete attributes)
raw.msg.html <- Base64URL_Decode_To_Char(eg.msg.resp.raw.data)
raw.msg.oneline <- gsub('\r\n','',gsub('=\r\n','',raw.msg.html))
questionably.encoded.msg.html <- strsplit(raw.msg.oneline, "Content-Transfer-Encoding: quoted-printable")[[1]][2]
```
>
> R currently lacks a URL-safe base64 library, so this all begins to get complicated quite quickly - at the end of the above, after *string manipulation* you're left with output littered in `3D`s from the `%3D` encoding of `=`... long story short I chose 'full' format instead.

This side of the package seems unfinished - the `gmailr` URL-safe base64 decoding function seems to be internal, `messages()` and `message()` methods are undocumented, but the full, URL-safe base64-, UTF-8-encoded message HTML can be read by setting a couple of functions up outside the scope of `message()`, peppered with a handful of `\r\n` line breaks to be stripped away:

```r
library('base64enc')
Base64URL_Decode_To_Char = function(x) { rawToChar(Base64URL_Decode(x)) }
Base64URL_Decode = function(x) { base64decode(gsub("_", "/", gsub("-", "+", x))) }

eg.msg.html <- gsub('\r\n','',Base64URL_Decode_To_Char(eg.msg.resp.full.data))
```

###2: Message parsing

There are two kinds of Google Scholar Alert: citations of a particular paper (which I won't use here) and custom results for a search query - I currently have one set up to keep an eye *microRNA oscillation* literature, and can filter the Scholar Alerts in my inbox for solely these with:

```r
scholar.alerts.mo <- messages('Scholar Alert microRNA oscillation')
mo.msg.list <- scholar.alerts.mo[[1]][['messages']]
eg.msg.id <- mo.msg.list[[1]][['id']]
```

Then proceed as above, but building a list of new papers by parsing the HTML with R's `XML` package:

```r
eg.msg.resp.data <- message(eg.msg.id, format = "full")$payload$body$data
eg.msg.html <- gsub('\r\n','',Base64URL_Decode_To_Char(eg.msg.resp.data))

library('XML')
mail.doc <- htmlParse(eg.msg.html, asText=TRUE, encoding = "UTF-8")
mail.root <- xmlRoot(mail.doc)
# See the XML package vignette for details: http://www.omegahat.org/RSXML/Tour.pdf
 
article.list <- xmlElementsByTagName(mail.root[["body"]][["div"]],"h3")

article.summaries <- lapply(article.list, GetPaper)
names(article.summaries) <- NULL
```

<pre>> article.summaries
[[1]]
[[1]]$title
[1] "A Dicer-miR-107 Interaction Regulates Biogenesis of Specific miRNAs Crucial for Neurogenesis"

[[1]]$url
[1] "http://www.sciencedirect.com/science/article/pii/S153458071400834X"


[[2]]
[[2]]$title
[1] "Notch in memories: Points to remember"

[[2]]$url
[1] "http://onlinelibrary.wiley.com/doi/10.1002/hipo.22426/abstract"


[[3]]
[[3]]$title
[1] "Glucocorticoids and 11β-hydroxysteroid dehydrogenases: mechanisms for hypertension"

[[3]]$url
[1] "http://www.sciencedirect.com/science/article/pii/S1471489215000065"</pre>

> <small>Side note: in writing that grep line I unearthed a [7 year old wiki page, *Computation on empty vectors in R*](https://github.com/lmmx/devnotes/wiki/Computation-on-empty-vectors) which is pretty cool.</small>

### 3: Tweeting papers

### 3.1: Write some strings

Twitter's 140 character limit makes an exception for links, which are always counted at a flat-rate of 23 characters, leaving a 116 character limit after a space. To indicate truncation it's standard to use three full stops, but better yet a single-character ellipsis ([U+2026](http://www.fileformat.info/info/unicode/char/2026/index.htm)), giving a 115 character limit.

For a domain-specific 'bot', it makes sense to at least attempt to maximise the information provided through abbreviation. For example, "MicroRNA" to "miRNA", or for an intrinsically disordered protein feed, "IDP", *etc.*

A function `AbbrevTitles` can be called across the list within a function to generate tweets, `WriteTweet`. For technical details on how this process works, see the [wiki page]() on it, but the main idea is that it shortens repeatedly from a dictionary of common abbreviations (`abbrev.list`) until within the character limit.

```r
abbrev.list <- list( microRNA = "miRNA",
                    "three-dimensional" = "3D",
                    "intrinsically disordered protein" = "IDP",
                    "intrinsically disordered region" = "IDR",
                    "double-stranded RNA" = "dsRNA",
                    "double-stranded DNA" = "dsDNA",
                    "single-stranded RNA" = "ssRNA",
                    "single-stranded DNA" = "ssDNA",
                    "RNA binding protein" = "RBP",
                    "DNA binding protein" = "DBP",
                    "RNA-sequencing" = "RNAseq",
                    "ribosomal RNA" = "rRNA",
                    "messenger RNA" = "mRNA",
                    "non-coding RNA" = "ncRNA",
                    "Escherichia coli" = "E. coli",
                    ribonuclease = "RNAse",
                    "nuclear magnetic resonance" = "NMR",
                    regulation = "reg.",
                    knockout = "k/o",
                    "protein-protein interaction" = "PPI",
#                    interaction = "intxn",
                    "et cetera" = "etc"
)
```

With the above (default) dictionary, a paper entitled "*A detailed three-dimensional structural analysis of the interaction of ribonuclease III with ribosomal RNA in Escherichia coli*" would be abbreviated as:

```r
AbbrevTitle(eg.title)
# [1] "A detailed 3D structural analysis of the interaction of RNAse III with rRNA in E. coli"
```

The `max.compact` parameter makes the title as compact as possible. If specified as `FALSE`, the title will only be shortened to fit within the character limit (though this potentially leads to arbitrary abbreviation of some words over others, hence default behaviour is to use all known abbreviations). If it still runs over the limit, it's truncated with '…'.

```r
eg.title <- "A detailed three-dimensional structural analysis of the interaction of ribonuclease III with ribosomal RNA in Escherichia coli"
AbbrevTitle(eg.title, max.compact = FALSE)
# [1] "A detailed 3D structural analysis of the interaction of ribonuclease III with ribosomal RNA in Escherichia coli"
```

The function to write a tweet is quite simple:

```r
WriteTweet <- function(article.summary) {
  tweet.title <- AbbrevTitle(article.summary$title)
  return(paste(c(tweet.title,article.summary$url),collapse=" "))
}

tweets <- lapply(article.summaries, WriteTweet)
```

<pre>> tweets
[1] "A Dicer-miR-107 Interaction Regulates Biogenesis of Specific miRNAs Crucial for Neurogenesis http://www.sciencedirect.com/science/article/pii/S153458071400834X"
[2] "Notch in memories: Points to remember http://onlinelibrary.wiley.com/doi/10.1002/hipo.22426/abstract"
[3] "Glucocorticoids and 11β-hydroxysteroid dehydrogenases: mechanisms for hypertension http://www.sciencedirect.com/science/article/pii/S1471489215000065"</pre>

### 3.2: Option 1: Send papers to Twitter

Firstly install [`twitteR`](https://github.com/geoffjentry/twitteR), with dependencies if needed:

```r
# install.packages(c("devtools", "rjson", "bit64", "httr"))
library('devtools')
# install_github("twitteR", username="geoffjentry")
# Install from my fork until PR is accepted
install_github("lmmx/twitteR")
library('twitteR')
```

Then authorise a new application in the [Twitter developer console](https://apps.twitter.com), which requires you to [verify a mobile number](https://twitter.com/settings/devices). Make sure to turn off the text notifications, which are all on by default.

![](Images/Img8TwitterDevConsoleAppCreate.png)

* Modify permissions to read and write
* In the *Keys and Access Tokens* tab, obtain the API 'key' and 'secret' (and generate a token on the same page, as the key and secret may not work).

#### Automate the storage of credentials with `CreateTwitterAuthFile()`

The default parameter for `authfile.name` is 'twitter_authfile.json', and after prompts the file is stored in the working directory.

`TwitterAuth()` wraps `setup_twitter_oauth` to authenticate using the same file (again a different file can be specified with the `authfile.name` parameter). See the [wiki page for manual authenication details](https://github.com/lmmx/ScholarDaemon/wiki/Manual-authentication-details).

To write a tweet uses the `updateStatus()` function, which in the source repo doesn't bypass the 140 character limit (we already take t.co URL shortening into account with `abbrevTitles()` before passing a tweet to the API call).

> As well as the core `text` parameter, a `mediaPath` can also be passed to `updateStatus`, so pictures such as graphical abstracts could potentially be supplied this way. You can also `searchTwitter`, `getUser`, `twListToDF`, `userTimeline`, `homeTimeline` - see the [vignette](http://geoffjentry.hexdump.org/twitteR.pdf) for details.

```r

```

### 3.3: Option 2: Send papers to the Buffer API with `RProtoBuf`

### 4: Gmail checker automation

### 4.1: Part 1: Cron

### 4.2: Part 2: Amazon EC2