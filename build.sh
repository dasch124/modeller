#!/bin/bash
listingHtmlFilenamePattern="listing_#.html"
listingsXPathExpr="h:code[@data-type='listing']"
listingsXPathExprM="//code"
export schemaFilename="model.rng"

setup() {
	if [ ! -e "$libdir" ]
	then
		mkdir "$libdir"
	fi 
	echo "\$scriptdir=$scriptdir"
	echo "\$libdir=$libdir"


	if [ ! -f "$libdir/owl-x86_64-linux-snapshot" ]
	then
		wget https://github.com/atextor/owl-cli/releases/download/snapshot/owl-x86_64-linux-snapshot -O "$libdir/owl-x86_64-linux-snapshot"
		chmod u+x "$libdir/owl-x86_64-linux-snapshot"
	fi

	if [ ! -f "$libdir/saxon/saxon-he-11.3.jar" ]
	then
		mkdir "$libdir/saxon"
		wget https://altushost-swe.dl.sourceforge.net/project/saxon/Saxon-HE/11/Java/SaxonHE11-3J.zip -O "$libdir/saxon/SaxonHE11-3J.zip"
		cd "$libdir/saxon"
		unzip *.zip
	fi
#
#	if [ ! -f "$libdir/base64.xsl" ]
#	then
#		wget https://raw.githubusercontent.com/ilyakharlamov/xslt_base64/master/base64.xsl -O "$libdir/base64.xsl"
#	fi
#
#	if [ ! -f "$libdir/base64_binarydatamap.xml" ]
#	then 
#		wget https://raw.githubusercontent.com/ilyakharlamov/xslt_base64/master/base64_binarydatamap.xml -O "$libdir/base64_binarydatamap.xml"
#	fi
	return 0
}

saxon() {
	debug "saxon $@"
	java -jar $libdir/saxon/saxon-he-11.3.jar $@
}

expandModel() {
	# expands xincludes in the model
	# model=path to the model document
	model=$1
	output="$workingdir/modelFull.xml"
	debug "saxon -s:$model -xsl:"$scriptdir/it.xsl" -o:"$output" -xi:on"
	saxon -s:$model -xsl:"$scriptdir/it.xsl" -o:"$output" -xi:on
	echo $output
}	

highlight() {
	# html = the path to the html file containing the code examples to be highlighted
	html=$1
	# model = the path to the expanded model.xml file
	model=$2
	debug "** highlighting code listings **"
	debug "\$html=$html"
	debug "\$model=$model"
	c=`xmlstarlet sel --xinclude -N h='http://www.w3.org/1999/xhtml' -t -v "count(//$listingsXPathExpr)" $html`
	for i in $(seq "$c"); do 
		lang=`xmlstarlet sel -N h='' -t -v "($listingsXPathExprM)[$i]/@language" $model`
		name=`xmlstarlet sel -N h='' -t -v "($listingsXPathExprM)[$i]/ancestor::*[name]/name" $model`
		listingHtml=`echo $listingHtmlFilenamePattern | sed -r "s/#/$i/"`
		if [[ -z $name ]];
		then 
			echo "no \$name found for $listingsXPathExprM[$i] – exiting"
			xmlstarlet sel -t -v "($listingsXPathExprM)[$i]/parent::*" $model
			exit 1
		fi
		debug "processing code example number $i: $lang / $name > $workingdir/$listingHtml"
		code=`xmlstarlet sel -N h='http://www.w3.org/1999/xhtml' -t -c "(//$listingsXPathExpr)[$i]/node()" $html`
		doFormat "$code" $lang | doHighlight $lang > "$workingdir/$listingHtml"
	done
}

doHighlight(){
	# moving from source-highlight to pygmentize because it supports more languages
	# source-highlight --src-lan $lang -o "$workingdir/$listingHtml"
	debug "*** doHighlight($@) ***"
	lang=$1
	if [ -z "$lang" ];
	then 
		debug "no \$lang provided, passing on as-is "
		echo "<div>$1</div>"
	else 
		debug "pygmentize -O noclasses -f html -l $lang | xmllint --html --xmlout - | xmlstarlet sel -t -c //div[@class = 'highlight']"
		pygmentize -O noclasses -f html -l $lang | xmllint --html --xmlout - | xmlstarlet sel -t -c "//div[@class = 'highlight']"
	fi
}

doFormat() {
	code=$1
	lang=$2
	case $lang in
		xml)
			output=`echo -n "$code" | xmlstarlet fo -o`
			;;
		turtle)
			code=`echo "$code"| xmlstarlet unesc`
			output=`echo "$code" | lib/owl-x86_64-linux-snapshot write - -v` 
			;;
		*)
			output=`echo -n $code`
			;;
	esac
	echo -n "$output"
}

toImg() {	
	echo "*** toImg() ***"
	debug "*** toImg() ***"
	html=$1
	format=$2
	debug "\$html=$html"
	debug "\$format=$format"
	
	c=`xmlstarlet sel --xinclude -N h='http://www.w3.org/1999/xhtml' -t -v "count(//$listingsXPathExpr)" $html`
	for i in $(seq "$c"); do 
		listingHtmlFilename=`echo $listingHtmlFilenamePattern | sed -r "s/#/$i/"`
		imgFilename=`echo $imgFilenamePattern | sed -r "s/#/$i/"`
		debug "\$imgFilename=$imgFilename"
		cat "$workingdir/$listingHtmlFilename" | wkhtmltoimage -f $format - "$workingdir/$imgFilename"
	done
	debug "*** done toImg() ***"
}

embedImgs() {
	html=$1
	imgDataXML="$workingdir/imageData.xml"
	debug "*** embedImgs() ***"
	debug "\$imgDataXML=$imgDataXML"
	debug "\$workingdir=$workingdir"
	debug "\$html=$html"
	echo "<_>" > $imgDataXML
	c=`xmlstarlet sel --xinclude -N h='http://www.w3.org/1999/xhtml' -t -v "count(//$listingsXPathExpr)" $html`
	debug "found $c images in $html"
	for i in $(seq "$c"); do 
		listingHtmlFilename=`echo $listingHtmlFilenamePattern | sed -r "s/#/$i/"`
		imgFilename=`echo $imgFilenamePattern | sed -r "s/#/$i/"`
		echo "<img format='image/$imgFormat' src='"$workingdir/$listingHtmlFilename"'>" >> $imgDataXML
		cat "$workingdir/$listingHtmlFilename" | wkhtmltoimage -f $imgFormat - "$workingdir/$imgFilename" 
		if [ $imgFormat != "svg" ];
		then 
			debug "base64 "$workingdir/$imgFilename" >> $imgDataXML"
			base64 "$workingdir/$imgFilename" >> $imgDataXML
		else 
			xmlstarlet sel -N svg='http://www.w3.org/2000/svg' -t -c "//svg:svg" "$workingdir/$imgFilename" >> $imgDataXML
		fi
		echo "</img>" >> $imgDataXML
		echo "" >> $imgDataXML
	done

	c=`xmlstarlet sel -N h='http://www.w3.org/1999/xhtml' -t -v "count(//h:img[@src])" $html`
	for i in $(seq "$c"); do 
		src=`xmlstarlet sel -N h='http://www.w3.org/1999/xhtml' -t -v "(//h:img[@src])[$i]/@src" $html`
		mimetype=`file -b --mime-type "$src"`
		echo "<img format='$mimetype' src='$src'>" >> $imgDataXML
		debug "base64 "$src" >> $imgDataXML $mimetype"
		base64 "$src" >> $imgDataXML
		echo "</img>" >> $imgDataXML
		echo "" >> $imgDataXML
	done
	
	echo "</_>" >> $imgDataXML

	cat "$scriptdir/injectListing.xsl.tmpl" | while read line;  do echo "${line/\$listingsXPathExpr/$listingsXPathExpr}"; done > "$workingdir/injectListing.xsl"
	
	debug "saxon -xsl:"$workingdir/injectListing.xsl" -s:$html imgFilnamePattern=$imgFilenamePattern pathToImageDataXML="$imgDataXML" workingdir="$workingdir" listingsXPathExpr="$listingsXPathExpr" $parameters $debugxsl"
	saxon -xsl:"$workingdir/injectListing.xsl" -s:$html imgFilnamePattern=$imgFilenamePattern pathToImageDataXML="$imgDataXML" workingdir="$workingdir" listingsXPathExpr="$listingsXPathExpr" $parameters $debugxsl
}


toDot() {
	# transforms the model document to a dot file and renders it as an image
	# inputfile: the absolute path to the model document
	# returns the path to the generated image file
	inputfile=$1
	outputfile=$2
	if [[ -z "$outputfile" ]];
	then 
		dotoutputfile="$workingdir/$inputfile.dot"
	else 
		dotoutputfile="$workingdir/$outputfile.dot"
	fi
	imgoutputfile="$dotoutputfile.$imgFormat"
	debug "*** toDot() ***"
	debug "\$inputfile=$inputfile"
	debug "\$dotoutputfile=$dotoutputfile"
	debug "\$imgoutputfile=$imgoutputfile"
	debug "saxon -xsl:$scriptdir/model2dot.xsl  -s:$inputfile -o:$dotoutputfile -xi:on $parameters $debugxsl"
	saxon -xsl:"$scriptdir/model2dot.xsl" -s:$inputfile -o:"$dotoutputfile" -xi:on $parameters $debugxsl

	if [ $? -eq 0 ]; then debug "wrote dotfile to $dotoutputfile"; else echo "an error occured transforming xml to dot"; exit $?; fi
	debug "dot $dotoutputfile -T$imgFormat -o $imgoutputfile" 	
	
	dot "$dotoutputfile" -T$imgFormat -o "$imgoutputfile" 
	if [ $? -ne 0 ]; then echo "an error occured running dot on $dotoutputfile"; exit $?; fi
	echo $imgoutputfile
}

model2html() {
	# transforms the model document to a html file, including listings as html and references the graph image
	# model: the model document to be processed
	# pathToModelDot: the path to the overview graph image
	model=$1
	pathToGraphImage=$2
	debug "** model2html $model $pathToGraphImage **"
	html="$workingdir/$inputfile.html"
#	relPathToGraphImage=$(realpath --relative-to="$workingdir" $pathToGraphImage)
	debug "saxon -xsl:"$scriptdir/model2html.xsl" -o:$html -xi:on -s:$model pathToGraphImage=$pathToGraphImage $parameters $debugxsl"
	saxon -xsl:"$scriptdir/model2html.xsl" -o:$html -xi:on -s:$model pathToGraphImage="$pathToGraphImage" $parameters $debugxsl
}

validate() {
	file=$1	
	pathToSchema=$(xmlstarlet sel -t  -v '//processing-instruction("xml-model")' $file | grep --only-matching -P '(?<=href=").+?(?=")')
	debug "*** validate() ***"
	[ -z "$pathToSchema" ]  && pathToSchema=$(realpath $scriptdir/$schemaFilename)

	if [ ! -f "$pathToSchema" ]
	then
		echo "schema not found '$pathToSchema'"
		exit 1
	fi 
	echo "using schema $pathToSchema"
	xmllint --noout --xinclude --relaxng "$pathToSchema" $file && echo "$file validates against $pathToSchema" || exit 1
}


generateTemplates() {
	outputdir=$1
	echo "** writing templates to $outputdir **"
	pushd "$scriptdir"
	pathToSchema=$(realpath "$schemaFilename")
	cp "./templates/model.xml" "$outputdir/."
	cp "./templates/class.xml" "$outputdir/."
	sed -i "s|\$pathToSchema|$pathToSchema|" "$outputdir/model.xml"
	sed -i "s|\$pathToSchema|$pathToSchema|" "$outputdir/class.xml"
	popd
	exit 0
}

generateDocs() {
	# inputfile: the model xml document (with unexpanded xincludes)
	inputfile=$1
	# outputfile: the filename to write the output to
	outputfile=$2
	debug "*** generateDocs '$inputfile' '$outputfile' ***"

	# check for presence of $inputfile
	if [ ! -f "$inputfile" ]; then	echo "file not found '$inputfile'";  exit 1; fi 

	validate $inputfile

	echo "** processing $inputfile **"

	dotfilepath=$(toDot "$inputfile" "$ouputfile")
	debug "\$dotfilepath=$dotfilepath"
	# first we have to expand the xinlucdes in the model file
	model=`expandModel $inputfile`
	debug "\$model=$model"

	# transform to html
	model2html $model $dotfilepath

	debug "\$html=$html"
	
	# extract listings, highlight them and store to temporary html files
	debug "highlight $html `realpath $model`"
	highlight $html "`realpath $model`"

	
	# replace html:code with the highlighted files from the step above
	debug "saxon -xsl:"$scriptdir/replaceListingWithHighlightedHtml.xsl" -o:$html -s:$html listingHtmlFilenamePattern="$workingdir/$listingHtmlFilenamePattern" $parameters $debugxsl"
	saxon -xsl:"$scriptdir/replaceListingWithHighlightedHtml.xsl" -o:$html -s:$html listingHtmlFilenamePattern="$workingdir/$listingHtmlFilenamePattern" $parameters $debugxsl

	# since pandoc does not preserve custom CSS formatting when converting to docx
	# we need to convert the highlighted html code elements to images  
	# in a standalone html version
	if [ -z $(echo $parameters | grep -oP "(?<=imgFormat=)\w+") ];
	then imgFormat="svg"
	else imgFormat=$(echo $parameters | grep -oP "(?<=imgFormat=)\w+")
	fi

	toImg $html $imgFormat

	# … and replace the code elements with the resulting images –
	htmlStandalone=$(echo $html | sed "s/\.html/standalone.html/g")
	embedImgs $html | saxon -o:$htmlStandalone -s:- -xsl:"$scriptdir/it.xsl" $parameters 'stripNamespaces=true !include-content-type=no !method=html !version=5.0 !indent=no' 

	
	
	# afterwards we can convert to docx via pandoc
	version=$(xmlstarlet sel -t -v "/model/meta/version" $model)
	title=$(xmlstarlet sel -t  -v '/model/meta/title' $model)
	author=$(xmlstarlet sel -t  -v '//person[parent::contributor/@role="author"]/name' $model)
	debug "\$title=$title"
	debug "\$version=$version"
	debug "\$author=$author"
	docxPath="$workingdir/$outputfile.docx"
	debug "pandoc -s -f html -i $htmlStandalone -o "$docxPath" -M version="$version" -M title="$title" -M author="$author""
	pandoc -s -f html -i $htmlStandalone -o "$docxPath" -M version="$version" -M title="$title" -M author="$author"
	
	if [ $? -ne 0 ]; 
	then 
		echo "an error occured running pandoc $htmlStandalone"; 
		exit $?; 
	else
		debug "successfully wrote $docxPath"
	fi

	# clean up working directory
	mv $htmlStandalone "$modeldir/$outputfile.html"
	mv $docxPath "$modeldir/$outputfile.docx"
	echo "successfully wrote $modeldir/$outputfile.html + $modeldir/$outputfile.docx"
	if [[ $keeptmpfiles -ne 1 ]]; then rm -rf "$workingdir"; fi
	exit 0
}

debug() {
	if [[ $verbose -eq 1 ]]; then 
		caller=$(caller)
		echo $caller | grep -oP '^\d+' | tr '\012\015' '\t' >> $logfile
		echo "$1" >> $logfile
#		i=1;
#		for line in "$1"; do 
		#	if [ $i -gt 1 ]; then
		#		echo "\t\t" >> $logfile
		#	fi
		#	echo $line >> $logfile
		#done
	fi
}

printHelp() {
text="
** quick-and-dirty model to documentation script **

This script transforms a 'model description document' (conforming the schema $schemaFilename) to html and/or docx documentation.

-a: action to run: 
	* generateDocs: generate full documentation in docx
	* generateGraph: only generate graph image (format per default svg, otherwise pass 'imgFormat=png' as last parameter)
	* generateTemplates: generate empty xml templates to start fromt
	* setup: initial setup of folder structure and dependencies for processing
-i: input (XMl-enoded model) - obligatory for all actions except generateTemplates or setup
-o: ouptput filename (optional)
-v: verbose – write additional output (to a logfile and to stdout)
-l: name of the log file (implies -v)
-k: keep temporary files for debugging purposes
-p: parameters – passed to underlying commands
	* showAbstractSuperclasses=true: include abstract superclasses in the graph rendering
	* showProperties=true: show properties for classes
	* showCardinalities=true: show cardinalities for class properties (TODO relations)
	* imgFormat=(png|svg): the format of any images in the documentation
	* ranksep, nodesep: options to tweak dot graph output, cf. <https://graphviz.org/docs/attrs/ranksep/> and <https://graphviz.org/docs/attrs/nodesep/>
"
echo "$text"
exit 1
}

echo
while getopts 'a:i:o:p:l:kv' OPTION
do
case ${OPTION} in 
	a) ACTION="$OPTARG" ;;
	i) inputfile="$OPTARG" ;;
	o) outputfile="$OPTARG" ;;
	p) parameters="$OPTARG" ;;
	k) export keeptmpfiles=1 ;;
	v) export verbose=1 ;;
	l) logfile="$OPTARG" ;;
esac
done



if [[ -z "$(dirname "$(readlink -f "$0")")" ]];
then 
	scriptdir=$(pwd)
else
	scriptdir=$(dirname "$(readlink -f "$0")")
fi

export scriptdir
debug "\$scriptdir = $scriptdir"
export libdir="$scriptdir/lib"
export PATH="$PATH:$libdir"
parameters=$parameters 

if [ -z $(echo $parameters | grep -oP "(?<=imgFormat=)\w+") ];
then imgFormat="svg"
else imgFormat=$(echo $parameters | grep -oP "(?<=imgFormat=)\w+")
fi

imgFilenamePattern="$listingHtmlFilenamePattern.$imgFormat"
if [[ $verbose -eq 1 ]]; then
	if [[ -z $logfile ]]; 
	then 
		export logfile='build.log'; 
	else
		export logfile=$logfile
	fi
	export debugxsl="debug=true"
	echo "** debug run $(date) **" > $logfile
fi

debug "\$parameters=$parameters"


case $ACTION in
	generateDocs)
		if [[ -z "$inputfile" ]]; then
			echo "missing -i option (input)"
			exit 1
		else 
			if [[ -z $outputfile ]]
			then  outputfile="$(basename $inputfile .xml)"
			fi
			export modeldir=$(dirname `realpath $inputfile`)
			export workingdir="$modeldir/tmp"
			mkdir -p $workingdir
			generateDocs $inputfile $outputfile
		fi	
	;;
	
	generateTemplates)
		[ -z $outputfile ] && outputdir=`pwd`
		echo "writing to $outputdir"
		mkdir -p $outputdir
		generateTemplates $outputdir
	;;
	
	generateGraph) 
		if [[ -z "$inputfile" ]]; then
			echo "missing -i option (input)"
			exit 1
		else 
			validate $inputfile
			modeldir=$(dirname `realpath $inputfile`)
			export workingdir="$modeldir/tmp"
			if [ ! -e "$workingdir" ]
			then
				mkdir $workingdir 
			fi 
			outputfile="$workingdir/$inputfile.dot"
			dotFilepath=$(toDot "$inputfile")
			echo "$dotFilepath"
			exit 0
		fi
	;;

	setup)
		sudo dnf install pandoc graphviz libxml2 xmlstarlet python3-pygments wkhtmltopdf wget unzip
		setup 
		
	;;
		
	*)
		echo "undefined action '$ACTION'"
		printHelp
esac
