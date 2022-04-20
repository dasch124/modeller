#!/bin/bash
listingHtmlFilenamePattern="listing_#.html"
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
	java -jar $libdir/saxon/saxon-he-11.3.jar $@
}

expandModel() {
	# expands xincludes in the model
	# model=path to the model document
	model=$1
	output="$workingdir/modelFull.xml"
	debug "xmlstarlet tr --xinclude "$scriptdir/it.xsl" $model > $output"
	xmlstarlet tr --xinclude "$scriptdir/it.xsl" $model > $output
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
	c=`xmlstarlet sel --xinclude -N h='http://www.w3.org/1999/xhtml' -t -v "count(//h:code)" $html`
	for i in $(seq "$c"); do 
		lang=`xmlstarlet sel -t -v "(//code)[$i]/@language" $model`
		name=`xmlstarlet sel -t -v "(//code)[$i]/ancestor::*[name]/name" $model`
		listingHtml=`echo $listingHtmlFilenamePattern | sed -r "s/#/$i/"`
		if [[ -z $name ]];
		then 
			echo "no \$name found for //h:code[$i] – exiting"
			xmlstarlet sel -t -v "(//code)[$i]/parent::*" $model
			exit 1
		fi
		debug "processing code example number $i: $lang / $name > $workingdir/$listingHtml"
		code=`xmlstarlet sel -N h='http://www.w3.org/1999/xhtml' -t -c "(//h:code)[$i]/node()" $html`
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
		debug "pygmentize -O noclasses -f html -l $lang | xmllint --html --xmlout - | xmlstarlet sel -t -c "//div[@class = 'highlight']""
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
	
	c=`xmlstarlet sel --xinclude -N h='http://www.w3.org/1999/xhtml' -t -v "count(//h:code)" $html`
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
	echo "*** embedImgs() ***"
	debug "*** embedImgs() ***"
	debug "\$imgDataXML=$imgDataXML"
	debug "\$workingdir=$workingdir"
	echo "<_>" > $imgDataXML
	c=`xmlstarlet sel --xinclude -N h='http://www.w3.org/1999/xhtml' -t -v "count(//h:code)" $html`
	for i in $(seq "$c"); do 
		listingHtmlFilename=`echo $listingHtmlFilenamePattern | sed -r "s/#/$i/"`
		#imgFilename=`echo $imgFilenamePattern | sed -r "s/#/$i/"`
		echo "<img format='image/$img' src='"$workingdir/$listingHtmlFilename"'>" >> $imgDataXML
		cat "$workingdir/$listingHtmlFilename" | wkhtmltoimage -f $imgFormat - "$workingdir/$imgFilename" | base64 
		base64 "$workingdir/$imgFilename" >> $imgDataXML
		echo "</img>" >> $imgDataXML
		echo "" >> $imgDataXML
	done

	c=`xmlstarlet sel -N h='http://www.w3.org/1999/xhtml' -t -v "count(//h:img)" $html`
	for i in $(seq "$c"); do 
		src=`xmlstarlet sel -N h='http://www.w3.org/1999/xhtml' -t -v "(//h:img)[$i]/@src" $html`
		mimetype=`file -b --mime-type "$workingdir/$src"`
		echo "<img format='$mimetype' src='$src'>" >> $imgDataXML
		base64 "$workingdir/$src" >> $imgDataXML
		echo "</img>" >> $imgDataXML
		echo "" >> $imgDataXML
	done
	
	echo "</_>" >> $imgDataXML

	debug "saxon -xsl:"$scriptdir/injectListing.xsl" -p imgFilnamePattern=$imgFilenamePattern pathToImageDataXML="$imgDataXML" workingdir="$workingdir" -o:$html $html"
	saxon -xsl:"$scriptdir/injectListing.xsl" -p imgFilnamePattern=$imgFilenamePattern pathToImageDataXML="$imgDataXML" workingdir="$workingdir" -o:$html $html 
}


toDot() {
	# transforms the model document to a dot file and renders it as an image
	# inputfile: the path to the model document
	# returns the path to the generated image file
	inputfile=$1
	dotoutputfile="$inputfile.dot"
	imgoutputfile="$dotoutputfile.$imgFormat"
	debug "*** toDot() ***"
	debug "\$inputfile=$inputfile"
	debug "\$dotoutputfile=$dotoutputfile"
	debug "\$imgoutputfile=$imgoutputfile"
	debug "saxon -xsl:$scriptdir/model2dot.xsl  -s:$inputfile -o:$dotoutputfile -xi:on $parameters"

	if [[ $verbose -eq 1 ]]; 
	then
	debugxsl="debug=true"
	fi
	debug "saxon -xsl:$scriptdir/model2dot.xsl  -s:$inputfile -o:$dotoutputfile -xi:on $parameters $debugxsl"
	saxon -xsl:"$scriptdir/model2dot.xsl"  -s:$inputfile -o:"$dotoutputfile" -xi:on $parameters $debugxsl

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
	pathToModelDot=$2
	debug "** model2html $model $pathToModelDot **"
	inputfile=$(basename $model)
	html="$workingdir/$inputfile.html"
	pathToModelDot=$(realpath --relative-to="$workingdir" $pathToModelDot)
	debug "\$inputfile=$inputfile"
	saxon -xsl:"$scriptdir/model2html.xsl" -o:$html -xi:on -s:$model pathToModelDot=$pathToModelDot pathToModelDir="$modeldir"
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
	# inputfile: the model xml document (unexpanded)
	inputfile=$1
	# outputfile: the filename to write the output to
	outputfile=$2
	debug "*** generateDocs '$inputfile' '$outputfile' ***"

	# check for presence of $inputfile
	if [ ! -f "$inputfile" ]; then	echo "file not found '$inputfile'";  exit 1; fi 

	validate $inputfile

	echo "** processing $inputfile **"

	dotfilepath=$(toDot "$inputfile")
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
	debug "saxon -xsl:replaceListingWithHighlightedHtml.xsl -p listingHtmlFilenamePattern="$workingdir/$listingHtmlFilenamePattern" -o:$html $html"
	saxon -xsl:"$scriptdir/replaceListingWithHighlightedHtml.xsl" -p listingHtmlFilenamePattern="$workingdir/$listingHtmlFilenamePattern" -o:$html $html

	# convert highlighted html code elements to svg or png 
	imgFormat=$(echo $parameters | grep -oP "(?<=imgFormat=)\w+") || "svg"
	toImg $html $imgFormat

	# … and replace the code elements with the resulting images –
	# unfortunately this is needed because pandoc does not retain the 
	# CSS styling of the listings.
	embedImgs $html
	pandoc -s --toc -f html -i $html -o "$inputfile.docx"
	echo "successfully wrote $inputfile.docx"

	# clean up working directory
	mv $html $modeldir
	if [[ $keeptmpfiles -ne 1 ]]; then rm -rf "$workingdir"; fi
	exit 0
}

debug() {
	if [[ $verbose -eq 1 ]]; then 
		echo "$1" >> build.log
	fi
}

printHelp() {
text="
** quick-and-dirty modeller **

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
while getopts 'a:i:o:p:kv' OPTION
do
case ${OPTION} in 
	a) ACTION="$OPTARG" ;;
	i) inputfile="$OPTARG" ;;
	o) outputfile="$OPTARG" ;;
	p) parameters="$OPTARG" ;;
	k) export keeptmpfiles=1 ;;
	v) export verbose=1 ;;
	l) export logfile="$OPTARG" ;;
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
imgFormat=$(echo $parameters | grep -oP "(?<=imgFormat=)\w+") || "svg"
imgFilenamePattern="$listingHtmlFilenamePattern.$imgFormat"
debug "\$parameters=$parameters"
debug "\$imgFormat=$imgFormat"
debug "\$imgFilenamePattern=$imgFilenamePattern"
if [[ $verbose -eq 1 ]]; then
	if [[ -z $logfile ]]; then export logfile="build.log"; fi
	echo "** debug run `date` **" > $logfile
fi

case $ACTION in
	generateDocs)
		if [[ -z "$inputfile" ]]; then
			echo "missing -i option (input)"
			exit 1
		else 
			outputfile=$outputfile || "$inputfile.docx"
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
