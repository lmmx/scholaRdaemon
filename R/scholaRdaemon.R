library('gmailr', warn.conflicts = F)
library('twitteR', warn.conflicts = F) #NB the version with modified statuses.R, https://github.com/lmmx/twitteR
library('RJSONIO', warn.conflicts = F)
library('base64enc', warn.conflicts = F)
library('XML', warn.conflicts = F)

# Authorise Gmail
gmail_auth('gmail_authfile.json')

# Gmail decoding functions
Base64URL_Decode_To_Char <- function(x) { rawToChar(Base64URL_Decode(x)) }
Base64URL_Decode <- function(x) { base64decode(gsub("_", "/", gsub("-", "+", x))) }

# Gmail parsing functions
GetPaper <- function(article) {
  # declare a function to capitalise the first letter of any ALL CAPS titles given by Google Scholar
  ReCap <- function(title.str) {
    if (isTRUE(as.logical(grep("[[:lower:]]", title.str, invert=TRUE)))) {
      uncap.str <- tolower(strsplit(titlestr, " ")[[1]])
      return(paste(toupper(substring(uncap.str, 1,1)), substring(uncap.str, 2), sep="", collapse=" "))
    }
    else return(title.str)
  }
  
  list("title" = sapply(xmlValue(article[["a"]]), ReCap, USE.NAMES = F),
       "url" = strsplit(strsplit(xmlAttrs(article[["a"]])[["href"]], "scholar.google.co.uk/scholar_url\\?url=")[[1]][2], "\\&hl=en&sa=X\\&scisig=")[[1]][[1]])
  # removes Google's prefix + suffix to give the source URL
}

# Twitter authorisation functions
ReadNewVar <- function(prompt, new.var, onError = function(){return('')}, env = sys.frame()) {
  cat(prompt,': ',sep='')
  assign(new.var, readLines(n=1), 1)
  if (env[[new.var]] == '') cat(onError())
}

CreateTwitterAuthfile <- function(authfile.name = 'twitter_authfile.json') {
  abortAuth <- function() { stop("Re-run CreateTwitterAuthFile() when you have both API and token keys and secrets. Instructions on how to do so are available in the README at https://github.com/lmmx/scholaRdaemon") }
  cat('You need to set up Twitter authorisation at https://apps.twitter.com - enter your access credentials below (hit enter to abort)\n')
  #  ReadNewVar('API key','api_key_entered', onError = abortAuth())
  #  ReadNewVar('API secret','api_secret_entered', onError = abortAuth())
  #  ReadNewVar('Token key','token_key_entered', onError = abortAuth())
  #  ReadNewVar('Token secret','token_secret_entered', onError = abortAuth())
  
  # I rewrote the 4 lines above as lapply and sapply, while it's useful to be able to do I think it's obfuscating
  # ... in fact it doesn't work, because parent.frame() is modified by the function nesting. Need parent.frame(4) to reach GlobalEnv
  # ...... passing in sys.frame() being called from standardises the function :-)
  
  # for each credential listed, assign a new variable, named by lowering the user prompt to snake case and appending '_entered'
  lapply(c('API key','API secret','Token key','Token secret'),
         function(user.message) {
           do.call(ReadNewVar, as.list(sapply(user.message, function(credential){
             c(
               user.message,
               paste0(gsub(' ','_',tolower(credential)),'_entered'),
               'onError = abortAuth()')
           })))
         })
  
  json.string <- paste0('{"info":{"consumer_key":"',api_key_entered,'","consumer_secret":"',api_secret_entered,'","access_token":"',token_key_entered,'","access_secret":"',token_secret_entered,'"}}')
  twitter.authfile <- file(authfile.name)
  write(json.string, file = twitter.authfile)
  close(twitter.authfile)
  
  cat('\nCredentials stored in',authfile.name)
}

scholaRdaemonConfig <- function(config.filename = 'sd_config.json') {
  cat('Enter the default query your Google Scholar Alerts are set up for (will be used to find new results)\n')
  abortSDConfig <- function() { stop("Re-run scholaRdaemonConfig() to set up default settings.") }
  
  lapply(c('Gmail search term'),
         function(user.message) {
           do.call(ReadNewVar, as.list(sapply(user.message, function(credential){
             c(
               user.message,
               paste0(gsub(' ','_',tolower(credential)),'_entered'),
               'onError = abortSDConfig()')
           })))
         })
  
  json.string <- paste0('{"info":{"gmail_query":"',gmail_search_term_entered,'"}}')
  sd.configfile <- file(config.filename)
  write(json.string, file = sd.configfile)
  close(sd.configfile)
  assign('sd.config', ReadSDConfig(), 1) # passes the sd.config object up the stack
  cat('\nSearch query stored in',config.filename)
}

ReadSDConfig <- function() { return(fromJSON('sd_config.json')$info) }

# Create a Scholar Daemon config file if one doesn't exist

if (file.exists('sd_config.json') && !exists('sd.config')){
  sd.config <- ReadSDConfig()
} else scholaRdaemonConfig()

# Create a Twitter authorisation file if one doesn't exist
# NB will ignore any alternatively named JSON

if (!file.exists('twitter_authfile.json')) {
  CreateTwitterAuthfile()
}

TwitterAuth <- function(authfile.name = 'twitter_authfile.json') {
  cat('\nAuthorising Twitter\n')
  twitter.authinfo <- fromJSON('twitter_authfile.json')$info
  if (length(twitter.authinfo) == 2 && file.exists('.httr-oauth')) {
    h.o.file <- readRDS('.httr-oauth')
    h.o.tok.creds <- c(access_token = h.o.file[[1]]$credentials$oauth_token, access_secret = h.o.file[[1]]$credentials$oauth_token_secret)
    do.call(setup_twitter_oauth, c(as.list(twitter.authinfo), as.list(h.o.tok.creds)))
  } else do.call(setup_twitter_oauth, as.list(twitter.authinfo))
}

TwitterAuth()

# Dictionary and functions for abbreviating paper titles

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
                     #                    interaction = "intxn", # Not the most obvious abbreviation so commenting it out
                     "et cetera" = "etc"
)

InCharLimit <- function(tweet.url.string = '') {
  # Cautious: assume link will be longest possible (https, 23 characters)...
  url.char.count <- https.chars <- 23L
  http.chars <- 22L
  # https://dev.twitter.com/overview/t.co
  
  # ...unless it is proven otherwise
  if (confirmed.http <- grepl('http://',tweet.url.string))
    url.char.count <- http.chars
  
  return(title.char.limit <- 140L - url.char.count - 1)
}
# when calling AbbrevTitle on the title such that the URL (hence char. lim.) is taken into account

AbbrevTitle <- function(start.str, known.url = NULL, use.abbreviations = T, max.compact = T, above.env = parent.frame()) {
  
  if (!is.null(known.url)) char.limit <- InCharLimit(known.url) else char.limit = 116L
  
  working.title <- start.str
  if (nchar(working.title) > char.limit || max.compact) {
    
    # recursively substitute words from this 'dictionary' until below the 115 character limit,
    # otherwise resort to truncating with an ellipsis
    
    # Problem arises in splitting on word boundaries (including hyphens, for example microRNA-mediated)
    # --- How to restore string case without assuming words and capitalisation are unique? ---
    #       - potential non-unique 'names', e.g. "A review of a study on Escherichia coli ribonuclease A"
    #         has 3 non-equivalent names ('words') for "a"
    # Solution: keep another dictionary of the original upper case as names to the lower-case version
    
    lowered.words <- as.list(lapply(strsplit(start.str, "\\W", perl = TRUE), tolower)[[1]])
    names(lowered.words) <- strsplit(start.str, "\\W", perl = TRUE)[[1]]
    
    # --- How to reconstruct the string in the right order? ---
    # Solution:  1 map original case word substrings to start/end positions in the title string
    #            2 map lowercase words (noting their position in the lowered.words list)
    #              to abbreviations in abbrev.list, in order, where possible
    #            3 map lowercase words that have undergone abbreviation back to original case
    #              through the dictionary, using list position
    #            4 map original case words that have undergone abbreviation back to the title string
    #                 - this will involve recursively shortening the string and comparing lowercase
    #                   substring to lowercase [remaining] original string, possibly with punctuation
    #            5 replace the abbreviated words in the original string with abbreviations
    
    # Step 1
    # Firstly, check if it's possible to reconstruct word boundaries by simply joining with spaces
    # (which will obviously only potentially work for the first abbreviation)
    title.map.progress <- word.start.pos <- 1L
    words.mapped <- 0L
    last.replace.end <- 0L
    for (word in names(lowered.words)) {
      words.mapped <- words.mapped + 1L
      word.start.pos <- as.integer(regexpr(word,substring(start.str, title.map.progress))) + title.map.progress - 1L
      intwl <- as.integer(nchar(word))
      word.end.pos <- word.start.pos + intwl - 1L
      attr(lowered.words[[words.mapped]], "parsed.num") <- words.mapped
      attr(lowered.words[[words.mapped]], "start.pos") <- word.start.pos
      attr(lowered.words[[words.mapped]], "end.pos") <- word.end.pos
      title.map.progress <- word.end.pos
    }
    
    # Step 5 (callback function!)
    # Replace the abbreviated words in the original string with abbreviations
    SubstituteInTitle <- function(abbreviation, word.positions.to.replace, env = parent.frame()) {
      replace.start <- attr(lowered.words[[word.positions.to.replace[[1]]]], 'start.pos') + length.change
      
      # The abbreviation approach is valid only when replacing to the right of earlier abbreviations,
      # or else the positions' offset as determined by cumulative reductions in string length won't be valid.
      # Recursion over the assignment of positions and going left to right per abbreviation overcomes this.

      if (replace.start < env$last.replace.end) {
        if (nchar(working.title) > char.limit ) { return(NA)
          # can't break here, there's no loop for break/next, and will cause a jump to top level
          # annoyingly this means assignment of subbed.title has to be split up to first check the value !is.na
          # if too long, will induce break out of the for loop, down to ellipsis truncation
        } else return(working.title) # otherwise return the abbreviated string
      }
      
      replace.end <- attr(lowered.words[[rev(word.positions.to.replace)[[1]]]], 'end.pos') + length.change
      replace.range <- c(replace.start, replace.end)
      before.range <- substr(working.title, 1, replace.start-1)
      after.range <- substring(working.title, replace.end+1)
      abbreviated.title <- paste0(before.range, abbreviation, after.range)
      env$last.replace.end <- replace.end
      return(abbreviated.title)
    }
    
    #    browser()
    #    debug here, avoid the setup stages
    
    # Step 2
    # Find abbreviations to make
    searchlist <- tolower(names(abbrev.list))
    searchlist.pos <- 0L
    length.change <- 0L
    for (i in searchlist) {
      searchlist.pos <- searchlist.pos + 1L
      splitabbrev <- strsplit(i, "\\W", perl = TRUE)[[1]]
      
      # if splitting a lowercase-rendered abbreviation at word boundaries matches up to the same
      # process in the title, and if matches are consecutive, in the same order as the abbreviation
      
      abbrev.word.pos.list <- lapply(splitabbrev, function(this.word) which(lowered.words == this.word))
      
      # possible scenario: abbrev.word.pos.list <- lapply(c("double","stranded","dna"), function(this.word) {
      #   which(c("a","dna","paper","about","double", "stranded","dna","and","single","stranded","rna")
      #    == this.word) } )
      # ==> list(5,c(6,10),c(2,7))
      # match() will always match substrings at the first occurence, so this isn't acceptable
      # the best approach is to create a combinatorial data frame with expand.grid, but only if necessary
      needs.combi <- !all(lapply(abbrev.word.pos.list,length) == 1)
      
      if (needs.combi) {
        combi.df <- do.call(expand.grid, abbrev.word.pos.list)
        # find all possible combinations of the word position numeric vectors
        combi.consec <- Filter(Negate(is.null), apply(combi.df, 1, function(dfrow) if(all(diff(as.numeric(dfrow)) == 1)) {return (dfrow)} ))
        if (is.null(combi.consec)) next
        # return any consecutive sequence(s) within these possible combinations,
        # skipping this abbreviation if none are found
        
        # multiple means there are multiple abbreviations to be made,
        # single means you can proceed as for the non-combi case
        if (single.seq <- (length(combi.consec) == 1)) consec.seq <- as.vector(combi.consec[[1]])
      } else if (single.seq <- all(diff(as.numeric(abbrev.word.pos.list)) == 1)) {
        consec.seq <- unlist(abbrev.word.pos.list)
      } else next # this abbreviation isn't found in the title
      
      if (single.seq) { # i.e. if only 1 abbreviation to make
        pre.processed <- SubstituteInTitle(abbrev.list[[searchlist.pos]], consec.seq)
        if (!is.na(pre.processed)) subbed.title <- pre.processed else break
        
        length.change <- as.integer(length.change + nchar(subbed.title) - nchar(working.title))
        if (nchar(subbed.title) > char.limit || max.compact) {
          working.title <- subbed.title
          next # try another abbreviation on the updated title string
        } else {
          working.title <- subbed.title
          return(working.title) # success!
        }
      } else { # do the same over a list of multiple instances of the same abbreviation
        for (each.combination in combi.consec) {
          each.consec.seq <- as.vector(each.combination)
          pre.processed <- SubstituteInTitle(abbrev.list[[searchlist.pos]], each.consec.seq)
          if (!is.na(pre.processed)) subbed.title <- pre.processed else break
          length.change <- as.integer(length.change + nchar(subbed.title) - nchar(working.title))
          working.title <- subbed.title
          if (nchar(working.title) <= char.limit && !max.compact) return(working.title)
        }
      } # continue through the loop for every possible abbreviation
    } # all possible abbreviations have now been attempted but still over character limit: truncate instead
    
    # this is reached either upon exhausting all possible matches or if the abbreviation steps R>L
    if (max.compact && length.change < 0L) {
      working.title <- AbbrevTitle(working.title, max.compact = T)
      return(working.title)
    }
    if (nchar(working.title) > char.limit) {
      truncatedstr <- gsub("^\\s+|\\s+$", "", substr(working.title,1,char.limit-1)) # trim potential space after last word
      return(paste0(truncatedstr,'\u2026')) # append an ellipsis to indicate the title was truncated
    } else return(working.title)
  } else return(start.str) # no need to abbreviate if the title is within the character limit
}

WriteTweet <- function(article.summary) {
#  browser()
  tweet.title <- AbbrevTitle(article.summary$title, known.url = article.summary$url)
  return(paste(c(tweet.title,article.summary$url),collapse=" "))
}

# Gmail message reading functions

ReadMail <- function(mail.id) {
  mail.resp.full <- message(mail.id, format = "full")
  mail.resp.full.data <- mail.resp.full$payload$body$data
  mail.resp.decoded <- gsub('\r\n','',Base64URL_Decode_To_Char(mail.resp.full.data))
  mail.doc <- htmlParse(mail.resp.decoded, asText=TRUE, encoding = "UTF-8")
  mail.root <- xmlRoot(mail.doc)
  article.list <- xmlElementsByTagName(mail.root[["body"]][["div"]],"h3")
  article.summaries <- lapply(article.list, GetPaper)
  names(article.summaries) <- NULL
  return(article.summaries)
}

GetMail <- function(search.query = sd.config[['gmail_query']]) {
  if (!exists('sd.config') && missing('search.query')) {
    cat('Set up a default search query')
    scholaRdaemonConfig()
    sd.config <- ReadSDConfig()

    if (exists('sd.config')) {
      search.query <- sd.config[['gmail_query']]
    }
  }
  
  message_query <- paste0('from:scholaralerts-noreply@google.com subject:Scholar Alert ',search.query)
  retrieved.messages <- messages(message_query)
  message.ids <- sapply(retrieved.messages[[1]][['messages']], function(x) {x$id})
  sapply(message.ids, ReadMail)
}

# Handling ID logs
WriteNewIDs <- function(ids, log.filename = 'gmail_id_log.json', overwrite.log = F) {
  if (exists('debug.mode')) return(NULL) # Don't mark papers as tweeted if you're just checking them
  suff <- if (length(ids) > 1) 's' else NULL
  cat(paste0('Writing new id',suff),':',paste0(ids, collapse=", "),'\n')
  
  seen.ids <- fromJSON(log.filename)$list_seen
  json.string <- paste0('{"list_seen":[',paste(shQuote(c(ids,seen.ids), type="cmd"), collapse=", "),']}')
  log.file <- file(log.filename)
  write(json.string, file = log.file, append = !overwrite.log)
  close(log.file)
}

CheckMessageHistory <- function(ids, log.filename = 'gmail_id_log.json', overwrite.log = F) {
  if (!file.exists(log.filename)) {
    WriteNewIDs(ids, log.filename, overwrite.log)
    # will proceed to use these IDs in tweets
  } else {
    # subset IDs to only those not in the JSON
    past.ids <- fromJSON(log.filename)$list_seen
    new.ids <- ids[!ids %in% past.ids]
    if (length(new.ids) == 0) {
      cat('\nNo new papers\n')
    } else {
#      cat('Found ', ,'new papers.\n')
      WriteNewIDs(new.ids) # should really do this after sending the tweets in case of error
      # then whip up some tweets
      new.summaries <- sapply(new.ids, ReadMail)
      if (length(new.ids) == 1) {
        new.tweets <- as.vector(unlist(lapply(new.summaries, WriteTweet)))
      } else { # Multiple messages - recurse across them, into a single list
        new.tweets <- as.vector(unlist(lapply(new.summaries, function(summaries) {
          as.vector(unlist(lapply(summaries, WriteTweet)))
          })))
      }
      
      # Send to Twitter API
      print(new.tweets)
      if (exists('debug.mode')) {
        cat("\nNo tweets sent\n")
        return
      } else {
        for (new.tweet in new.tweets) {
          updateStatus(new.tweet, bypassCharLimit = T)
        }
      }
    }
  }
}

CheckMail <- function(confirm = F) {
  if (confirm) {
    cat('\nCheck for papers now? Hit enter to confirm, or any other key to cancel:\n')
			confirm.var <- readLines(n=1)
			if (confirm.var != '') {
			  confirm.var <- 'Scholar Alerts not checked'
				return(NA)
			}
  }
  # Should add a preview...
  return(GetMail())
}

recent.papers <- CheckMail(confirm = !exists('no.confirm')) # set a variable no.confirm = T to skip tweet confirmation

if (all(!is.na(recent.papers))) { # the CheckMail function would return NA [once] if the user cancels mail checking
  recent.paper.mail.ids <- names(recent.papers) # not actually paper names, just the message IDs
  CheckMessageHistory(recent.paper.mail.ids)
}

# clean up namespace

remove('sd.config') # clears the bot-specific configuration (otherwise will be prompted to enter search query)