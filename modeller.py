import sys
import copy
import os
import saxonche
import argparse
from lxml import etree
from pathlib import Path
from graphviz import Source
from pygments import highlight
from pygments.lexers import XmlLexer
from pygments.lexers import TurtleLexer
from pygments.formatters import HtmlFormatter
import pandoc
import imgkit

schemaFilename="model.rng"
DEBUG=False
NSMAP={"h":"http://www.w3.org/1999/xhtml"}

def init(args):
    """populate the config dict and setup necessary paths"""
    config=vars(args)
    # the name of the input file with stripped extension
    config["inputFnNoExt"]=os.path.splitext(os.path.basename(config["input"]))[0] if config["input"] is not None else None
    
    # the directory in which the model document lives
    modelDir=os.path.dirname(config["input"])
    config["modelDir"]=modelDir
    
    # the directory in which temporary files are stored during the processing
    workingDir=modelDir+"/tmp"
    config["workingDir"]=workingDir
    
    # the directory where the code of scripts are living
    scriptDir=os.path.dirname(os.path.realpath(__file__))
    config["scriptDir"]=scriptDir

    # the directory in which necessary code is installed 
    # CHECKME is this needed?
    libDir=scriptDir+"/lib"
    config["libDir"]=libDir
    
    # the directory where final output files should be written to
    outputDir=expandPath(args.outputDir) if args.outputDir is not None else expandPath(modelDir)
    config["outputDir"]=outputDir
    
    outputFnNoExt=args.outputFilename if args.outputFilename != None else config["inputFnNoExt"]
    config["outputFnNoExt"]=outputFnNoExt

    # parse model and extract metadata
    if config["input"] is not None:
        modelXML=etree.parse(config["input"])
        config["model.source"]=modelXML
        config["model.title"]=modelXML.xpath("//title", namespaces=NSMAP)
        


    for i in ["modelDir", "workingDir", "scriptDir", "libDir", "outputDir"]:
        if not os.path.exists(i):
            os.mkdir(i)
    
    # the temp paths of the build artifacts in the working directory
    config["artifactsTmpPaths"]=[]

    # the paths to the final artifacts 
    config["artifacts"]=[]
    debug("init()")
    for key, value in config.items():
        debug(key+"="+str(value))
    return config


def transform(s, xsl, o, parameters={}):
    # processor keeps files open on Windows and in doing so prevents moving or copying them
    debug("running transform")
    debug("s="+s)
    debug("xsl="+xsl)
    debug("o="+o)
    for key, value in parameters.items():
        debug(f"parameters.{key}={value}")
    with saxonche.PySaxonProcessor(license=False) as proc:
        proc.set_configuration_property("xi", "on")
        saxon = proc.new_xslt30_processor()
        for k,v in parameters.items():
            saxon.set_parameter(name=k, value=proc.make_string_value(str(v)))
        exec = saxon.compile_stylesheet(stylesheet_file=os.path.abspath(xsl))
        exec.apply_templates_returning_file(source_file=os.path.abspath(s), output_file=os.path.abspath(o))
        if exec.exception_occurred:
            exec.get_error_message
            #for i in range(saxon.exception_count()-1):
            print(saxon.get_error_message())
            print(os.path.abspath(s)+" - "+os.path.abspath(xsl)+" -> "+os.path.abspath(o)+" failed")
        if os.path.exists(os.path.abspath(o)):
            return o
        else: 
            print("there was an error transforming "+s+" with stylesheet "+xsl)




def expandModel(config):
    """expands the model, returns path to the full model """
    scriptDir=config["scriptDir"]
    wd=config["workingDir"]
    s=config["input"]
    xsl=f"{scriptDir}/expand.xsl"
    o=f"{wd}/modellFull.xml"
    transform(s=s, xsl=xsl, o=o)
    return o


def toDocx(config):
    debug("toDocx")


    # highlight code listings in html code
    pathToHTMLFormatted=formatListings(config)
    config["pathToHTMLFormatted"]=pathToHTMLFormatted
    
    # replace html listings with images
    pathToHTMLFormattedWithImages=embedImages(config)
    config["pathToHTMLFormattedWithImages"]=pathToHTMLFormattedWithImages

    h=config["pathToHTMLFormattedWithImages"]
    debug("h="+h)
    pathToHTMLWithEmbeddedImages=embedImages(config)
    debug("pathToHTMLWithEmbeddedImages="+pathToHTMLWithEmbeddedImages)
    pathToDocx=os.path.splitext(h)[0]+".docx"
    doc = pandoc.read(file=h, format="html")
    pandoc.write(doc, format="docx", file=pathToDocx)
    debug("pathToDocx="+pathToDocx)
    
    return pathToDocx

def formatListings(config):
    """syntax-highlight code listings in the html output of the model"""
    # collect all the listings
    listingHtmlFilenamePattern="listing_#.html"
    # in html: /pre/code/{content}
    listingsXPathExpr="//h:code[@data-type='listing']"
    listingsXPathExprM="//code"

    htmlParsed=etree.parse(config["pathToHTML"])
    listingsHTML=htmlParsed.xpath(listingsXPathExpr,namespaces=NSMAP)

    for index, listing in enumerate(listingsHTML):
        highlighted=formatListing(listing)
        # pygmetize returns <div class="highlighted"><pre>…</pre><div> 
        # we replace the original <pre> with the generated <div>
        pre=listing.getparent()
        pre.getparent().replace(pre, highlighted)
    
    # inject pygments CSS into parsed HTML
    css=HtmlFormatter().get_style_defs('.highlight')
    stylesElt=etree.Element("{http://www.w3.org/1999/xhtml}style")
    stylesElt.set("ID", "pygmetize-css")
    stylesElt.text=css
    htmlParsed.find("//h:head", namespaces=NSMAP).append(stylesElt)
    
    pathToHTMLFormatted=os.path.splitext(config["pathToHTML"])[0]+"_formatted.html"
    htmlParsed.write(pathToHTMLFormatted, encoding="utf-8", xml_declaration=True, method="html")
    return pathToHTMLFormatted

def formatListing(node):
    lang=node.get('data-language')
    name=node.get('data-name')
    if lang == "xml":
        indented=etree.tostring(node[0])
        highlighted=highlight(indented, XmlLexer(), HtmlFormatter())
    elif lang == "turtle":
        highlighted=highlight(node.text, TurtleLexer(), HtmlFormatter())
    else:
        raise ValueError(f"unexpected value \"{lang}\" in attribute @language")
    hxml=etree.fromstring(highlighted)
    return hxml



def embedImages(config):
    pathToHTMLFormatted=config["pathToHTMLFormatted"]
    h=etree.parse(pathToHTMLFormatted)
    css=h.xpath('//h:style[@ID="pygmetize-css"]', namespaces=NSMAP)[0]
    
    # iterate over all highlights and create images out of them

    imgObjs=[]
    for index, listing in enumerate(h.xpath("//h:div[@class = 'highlight']", namespaces=NSMAP)):
        debug(listing.getparent())
        # render image and store to working directory
        imgObj=toImg(config, index, copy.deepcopy(listing), css.text)
        
        # create an img element and replace the listing with it
        imgElt=etree.Element("{http://www.w3.org/1999/xhtml}img")
        imgElt.set('src', imgObj["pathToImage"])
    
        listing.getparent().replace(listing, imgElt)
        
    
    pathToHTMLFormattedWithImages=os.path.splitext(pathToHTMLFormatted)[0]+"_standalone.html"
    h.write(pathToHTMLFormattedWithImages, method="html")
    return pathToHTMLFormattedWithImages

    


def toImg(config, index, node, css):
    template=etree.fromstring(f"<html xmlns='http://www.w3.org/1999/xhtml'><head><style>{css}</style></head><body/></html>")
    template.xpath("//h:body", namespaces=NSMAP)[0].append(node)
    htmlString=etree.tostring(template, encoding="utf-8", pretty_print=True, method="html").decode('utf-8')
    debug(htmlString)
    pathToImage=config["workingDir"]+"/img_"+str(index)+".png"
    imgkit.from_string(htmlString, pathToImage)
    imgDict ={
        "listingNo": index,
        "node": node,
        "pathToImage": pathToImage
    }
    debug(imgDict)
    return imgDict


def model2html():
    return


# def validate(config):
#     """Validate a document against the rngSchema. Returns a list of dicts of which each one represents a validation (or parsing) error."""
#     validationErrors = []
#     sch = extractSchematron(rngSchema)
#     try:
#         doc = etree.parse(path)
    
#         # relaxng validation
#         relaxng_doc = etree.parse(rngSchema)
#         relaxng = etree.RelaxNG(relaxng_doc)
#         relaxng.assertValid(doc)
        
#         # schematron validation
#         schErrs = schValidate(sch, path)
#         if len(schErrs) >= 1:
#             validationErrors = validationErrors + schErrs
    
#     except etree.XMLSyntaxError as e:
#         valErrObj = {
#             "type" : "error",
#             "message": str(e), 
#             "line": e.lineno,
#             "source": path, 
#             "location": "n/a",
#             "stage" : "parsing", 
#             "exceptionType": type(e).__name__
#         }
#         fvoInfo = fvoByLinenumber(path, e.lineno)
#         if fvoInfo:
#             valErrObj["fvoID"] = fvoInfo['id']
#             valErrObj["fvoResp"] = fvoInfo['resp']
#         return valErrObj
        
#     except etree.DocumentInvalid as e:
#         for error in e.error_log:
#             # we ignore rng errors about @schemaLocation since 
#             # that is needed for validation in the TEI-enricher
#             if error.message != "Invalid attribute schemaLocation for element TEI":
#                 location = "n/a" if error.path is None else error.path
#                 valErrObj = {
#                     "type" : "error",
#                     "message": error.message, 
#                     "line": error.line, 
#                     "source": path, 
#                     "location": location,
#                     "stage" : "relaxng", 
#                     "exceptionType": type(e).__name__
#                 }
#                 # DEBUG
#                 print(valErrObj)
#                 fvoInfo = fvoByLinenumber(path, error.line)
#                 if fvoInfo:
#                     valErrObj["fvoID"] = fvoInfo['id']
#                     valErrObj["fvoResp"] = fvoInfo['resp']
#                 validationErrors.append(valErrObj)
        
#         # if the document is invalid against the RNG, we still want to run schematron against it
#         schErrs = schValidate(sch, path)
#         if len(schErrs) >= 1:
#             validationErrors = validationErrors + schErrs
        
        
    
#     return validationErrors


def validate(config):
    doc=config["model.source"]
    referencedSchema=""#locate rng file
    if config["useReferencedSchema"] == True and referencedSchema is not None:
        rngSchema=referencedSchema
    elif config["modelSchema"] is not None:
        if os.path.exists(config["modelSchema"]):
            rngSchema=os.path.abspath(config["modelSchema"])
        elif os.path.exists(config["scriptDir"]+"/"+config["modelSchema"]):
            rngSchema=config["scriptDir"]+"/"+config["modelSchema"]
        else:
            rngSchema=config["scriptDir"]+"/model.rng"
        
    
    relaxng_doc = etree.parse(rngSchema)
    relaxng = etree.RelaxNG(relaxng_doc)
    relaxng.assertValid(doc)    

def generateTemplates():
    return

def generateDocs(config):
    # check validity of the input file
    validate(config)
    # generate dot via XSLT
    pathToGraphImage=generateGraph(config)
    config["pathToGraphImage"]=pathToGraphImage
    # expand x-includles
    pathToExpandedModel=expandModel(config)
    config["pathToExpandedModel"]=pathToExpandedModel
	
    # Currently we always need to transform to html
    pathToHTML=model2html(config)
    config["pathToHTML"]=pathToHTML

    if "html" in config["formats"]:
        config["artifactsTmpPaths"].append(pathToHTML)
    
    if "docx" in config["formats"]:
        tmpPathToDocx=toDocx(config)
        if not os.path.exists(tmpPathToDocx):
            print("generating docx from HTML was not successful")
            return
        else:
            config["artifactsTmpPaths"].append(tmpPathToDocx)

    moveArtifactsToFinalLocations(config)
    print("generated docs:")
    for p in config["artifacts"]:
        print(p)
    return

def moveArtifactsToFinalLocations(config):
    for a in config["artifactsTmpPaths"]:
        ext=os.path.splitext(a)[1]
        finalPath=config["outputDir"]+"/"+config["outputFnNoExt"]+ext
        os.rename(a, finalPath)
        debug("moving "+a+" --> "+finalPath)
        if os.path.exists(finalPath):
            config["artifacts"].append(finalPath)
        else: 
            print("error copying "+a+" to "+finalPath)

def model2html(config):
    """transform the model document to a html file, including listings as html and references the graph image"""
    debug("model2html")
    wd=config["workingDir"]
    s=config["pathToExpandedModel"]
    xsl=config["scriptDir"]+"/model2html.xsl"
    o=wd+"/"+config["inputFnNoExt"]+".html"
    transform(s=s,xsl=xsl,o=o,parameters=config)
    return o

def generateGraph(config):
    """transform the model document to a dot file and render it as an image
	returns the path to the generated image file"""
    debug("generateGraph")
    wd=config["workingDir"]
    xsl=f"{config['scriptDir']}/model2dot.xsl"
    o=wd+"/"+config['inputFnNoExt']+".dot"
    p=config
    pathToDot=transform(s=config["input"], xsl=xsl, o=o, parameters=p)
    s = Source.from_file(pathToDot, encoding="utf-8", engine="dot", format=config["imgFormat"])
    return s.render()

def config2params(config, otherParams=None):
    params={}
    for key, value in config.items():
        params[key]=str(value)
    
    if otherParams is not None:
        if type(otherParams) is dict:
            params={**params, **otherParams}
        elif type(otherParams) is list:
            for d in otherParams:
                config2params(config,d)
        else:
            raise ValueError('config2params: otherParams must be either a single dict or an array of dicts')
    return params

def debug(msg):
    if DEBUG:
        print(str(msg))


def main(args):
    global DEBUG
    DEBUG=args.debug 

    if args.action is None:
        parser.print_help()
        debug("Passed arguments:")
        for k, v in vars(args).items():
            debug(f'{k} = {v}')
        return
    
    elif args.action == "generateTemplates":
        generateTemplates(config)
    
    
    elif args.action == "generateDocs":
        config=init(args)

        if args.input is None:
            print("missing argument -i / --input")
            parser.print_help()
        generateDocs(config)
    
    elif args.action == "generateGraph":
        config=init(args)
        generateGraph(config)
    
    else: 
        parser.print_help()
        

def expandPath(path):
    return os.path.abspath(os.path.expanduser(path))




parser = argparse.ArgumentParser(
      prog='Modeller',
      formatter_class=argparse.RawDescriptionHelpFormatter)
parser.add_argument('-a','--action', nargs='?', default="help", help='the action to run', choices=["setup", "generateGraph", "generateDocs", "generateTemplates"])
parser.add_argument('-i','--input', type=expandPath,help='the path to the model document (obligatory for all actions except generateTemplates or setup)')
parser.add_argument('-f', '--formats', choices=["html", "docx"], help='the output formats to be generated', action='append', default=["html"])
parser.add_argument('-d', '--debug', help='switch on debuggin mode (storing intermediate files, verbose output)', action='store_true')
parser.add_argument('-o', '--outputFilename', help='output filename')
parser.add_argument('-O', '--outputDir', help='output directory (defaults to the directory of the input file)')
parser.add_argument('--showAbstractSuperclasses', default=False, help='include abstract superclasses in the graph rendering')
parser.add_argument('--showProperties', default=True, help='show properties for classes')
parser.add_argument('--showCardinalities', default=False, help='show cardinalities for class properties (TODO relations)')
parser.add_argument('--imgFormat', default='svg', choices=['svg', 'png'], help='the format of any images in the documentation')
parser.add_argument('--ranksep', default=0, help='ranksep parameter of dot (cf. <https://graphviz.org/docs/attrs/ranksep/>)')
parser.add_argument('--nodesep', default=0, help='nodesep parameter of dot (cf. <https://graphviz.org/docs/attrs/nodesep/>)')
parser.add_argument('--modelSchema', default="model.rng", help='name of the schema to be used (defaults to model.rng next to this python script)')
parser.add_argument('--useReferencedSchema', default=False, help='in case the model document contains a xml-model processing instruction, use the schema referenced there; otherwise use the default schema ')
args = parser.parse_args()
main(args)

