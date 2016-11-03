/*
* Copyright (c) 2016, California Institute of Technology.
* All rights reserved.  Based on Government Sponsored Research under contracts NAS7-1407 and/or NAS7-03001.
*
* Redistribution and use in source and binary forms, with or without modification, are permitted provided that the following conditions are met:
*   1. Redistributions of source code must retain the above copyright notice, this list of conditions and the following disclaimer.
*   2. Redistributions in binary form must reproduce the above copyright notice,
*      this list of conditions and the following disclaimer in the documentation and/or other materials provided with the distribution.
*   3. Neither the name of the California Institute of Technology (Caltech), its operating division the Jet Propulsion Laboratory (JPL),
*      the National Aeronautics and Space Administration (NASA), nor the names of its contributors may be used to
*      endorse or promote products derived from this software without specific prior written permission.
*
* THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS" AND ANY EXPRESS OR IMPLIED WARRANTIES,
* INCLUDING, BUT NOT LIMITED TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE DISCLAIMED.
* IN NO EVENT SHALL THE CALIFORNIA INSTITUTE OF TECHNOLOGY BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL,
* EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES;
* LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT,
* STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE,
* EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
*
* Licensed under the Apache License, Version 2.0 (the "License");
* you may not use this file except in compliance with the License.
* You may obtain a copy of the License at
*
* http://www.apache.org/licenses/LICENSE-2.0
*
* Unless required by applicable law or agreed to in writing, software
* distributed under the License is distributed on an "AS IS" BASIS,
* WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
* See the License for the specific language governing permissions and
* limitations under the License.
*/

/*
 * mod_oemstime.cpp: OnEarth module for leveraging time snapping from Mapserver requests
 * Version 1.1.1
 */

#include "mod_oemstime.h"

static const char *twmssserviceurl_set(cmd_parms *cmd, oemstime_conf *cfg, const char *arg) {
	cfg->twmssserviceurl = arg;
	return 0;
}

static void *create_dir_config(apr_pool_t *p, char *dummy)
{
	oemstime_conf *cfg;
	cfg = (oemstime_conf *)(apr_pcalloc(p, sizeof(oemstime_conf)));
    return cfg;
}

static int oemstime_output_filter (ap_filter_t *f, apr_bucket_brigade *bb) {
	request_rec *r = f->r;
	conn_rec *c = r->connection;
    oemstime_conf *cfg = static_cast<oemstime_conf *>ap_get_module_config(r->per_dir_config, &oemstime_module);
    char *srs = 0;
    char *format = 0;
    char *time = 0;
    char *layer_list = 0;
    char *current_layer = 0;

    srs = (char *) apr_table_get(r->notes, "oems_srs");
    format = (char *) apr_table_get(r->notes, "oems_format");
    time = (char *) apr_table_get(r->notes, "oems_time");
    layer_list = (char *) apr_table_get(r->notes, "oems_layers");
    current_layer = (char *) apr_table_get(r->notes, "oems_clayer");

    if ((srs != 0) && (format != 0) && (time != 0) && (current_layer != 0) && (cfg->twmssserviceurl != 0)) { // make sure no null values
		if ((ap_strstr(r->content_type, "text/xml") != 0) || (ap_strstr(r->content_type, "application/vnd.ogc.se_xml") != 0)) { // run only if Mapserver has an error due to invalid time or format

			// If this is the last layer (i.e. layer list is down to 1, no comma delimiters left), handle as a fatal error message, parse and modify the XML.
			if (!ap_strstr(layer_list, ",")) 
			{
				// Outgoing bucket brigade is stored in the filter context for re-use.
				struct filter_ctx *ctx = static_cast<filter_ctx *>(f->ctx);
				if (!ctx)
				{
					f->ctx = ctx = static_cast<filter_ctx *>(apr_palloc(r->pool, sizeof(filter_ctx*)));
					ctx->bb_out = apr_brigade_create(r->pool, c->bucket_alloc);
				}

				xmlParserCtxtPtr xmlctx = 0;
				xmlDocPtr doc = 0;
				apr_bucket_brigade *bb_out = ctx->bb_out;

				/* This loop handles incoming buckets, which are read and loaded into the XML parser. When the final bucket arrives,
				The XML is checked for validity, and then the <ServiceException> tag message is modified using an xpath search.
				The output XML string is then written to the output stream. */
			    for (apr_bucket *b = APR_BRIGADE_FIRST(bb); 
			    	b != APR_BRIGADE_SENTINEL(bb); 
			    	b = APR_BUCKET_NEXT(b))
			    {
			    	if (APR_BUCKET_IS_EOS(b) || APR_BUCKET_IS_FLUSH(b)) 
			    	{
			    		xmlParseChunk(xmlctx, 0, 0, 1);
			    		if (!xmlctx->valid)
			    		{
			    			ap_log_rerror( APLOG_MARK, APLOG_ERR, 0, r, "Can't parse Mapserver output: invalid XML");	
			    		}
			    		doc = xmlctx->myDoc;

	    		        xmlXPathContextPtr xpathCtx = xmlXPathNewContext(doc);
				        xmlXPathRegisterNs(xpathCtx, BAD_CAST "new", BAD_CAST "http://www.opengis.net/ogc");
				        const xmlChar *search_xpath = (const xmlChar *)"/new:ServiceExceptionReport/new:ServiceException/text()";
				        xmlXPathObjectPtr xpathObj = xmlXPathEvalExpression(search_xpath, xpathCtx);
				        const char* out_buf;
				        int out_size;
				        if (xpathObj->nodesetval) {
				            xmlNodeSetContent(xpathObj->nodesetval->nodeTab[0], (const xmlChar *)"The data for your request was not found.");    
				            xmlDocDumpMemory(doc, (xmlChar **)&out_buf, &out_size);
				        }

				        xmlXPathFreeObject(xpathObj);
				        xmlXPathFreeContext(xpathCtx);
				        xmlFreeDoc(doc);

    			    	ap_fwrite(f->next, bb_out, out_buf, out_size);

    			    	// Add EOS bucket to tail once we're done w/ the XML
			    		APR_BUCKET_REMOVE(b);
			    		APR_BRIGADE_INSERT_TAIL(bb_out, b);
			    		ap_pass_brigade(f->next, bb_out);
			    		return APR_SUCCESS;
			    	}

			    	const char *buf = 0;
			    	apr_size_t bytes;
			    	if (APR_SUCCESS != apr_bucket_read(b, &buf, &bytes, APR_BLOCK_READ)) {
						ap_log_rerror( APLOG_MARK, APLOG_ERR, 0, r, "Error reading bucket");
					}

					if (!xmlctx)
					{
						xmlctx = xmlCreatePushParserCtxt(NULL, NULL, buf, bytes, NULL);
						continue;
					}

					if (xmlParseChunk(xmlctx, buf, bytes, 0))
					{
						ap_log_rerror( APLOG_MARK, APLOG_ERR, 0, r, "Error reading XML");	
					}
		    }
		}

			int max_size = strlen(cfg->twmssserviceurl)+strlen(r->args);
			char *pos = 0;
			char *split;
			char *last;
			char *new_uri = (char*)apr_pcalloc(r->pool, max_size);
			apr_cpystrn(new_uri, cfg->twmssserviceurl, strlen(cfg->twmssserviceurl)+1);
			if (ap_strstr(srs, ":") == 0) {
				srs = ap_strcasestr(srs, "%3A");
				srs += 3;
			} else {
				srs = ap_strstr(srs, ":");
				srs += 1;
			}
			if (ap_strstr(cfg->twmssserviceurl, "{SRS}")) {
				split = apr_strtok(new_uri,"{SRS}",&last);
				while(split != NULL)
				{
					pos = split;
					split = apr_strtok(NULL,"{SRS}",&last);
				}
				new_uri = apr_psprintf(r->pool, "%s%s%s", new_uri, srs, pos);
			}

			new_uri = apr_psprintf(r->pool,"%s?request=GetMap&layers=%s&srs=EPSG:%s&format=%s&styles=&time=%s&width=512&height=512&bbox=-1,1,-1,1",new_uri, current_layer, srs, format, time);
			ap_internal_redirect(new_uri, r); // redirect for handling of time by mod_onearth
		}
    }

    return ap_pass_brigade(f->next, bb);
}

// Configuration options that go in the httpd.conf
static const command_rec cmds[] =
{
	AP_INIT_TAKE1(
		"TWMSServiceURL",
		(cmd_func) twmssserviceurl_set,
		0, /* argument to include in call */
		ACCESS_CONF, /* where available */
		"URL of TWMS endpoint" /* help string */
	),
	{NULL}
};

static void register_hooks(apr_pool_t *p) {
	ap_register_output_filter("OEMSTIME_OUT", oemstime_output_filter, NULL, AP_FTYPE_RESOURCE) ;
}

module AP_MODULE_DECLARE_DATA oemstime_module = {
    STANDARD20_MODULE_STUFF,
    create_dir_config, 0, 0, 0, cmds, register_hooks
};
