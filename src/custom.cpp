#include <iostream>
#include "../include/custom.h"
#include <curl/curl.h>

void searchForLinks(GumboNode *node, std::vector<std::string> &urls)
{
	if (node->type == GUMBO_NODE_ELEMENT)
	{
		if (node->v.element.tag == GUMBO_TAG_A)
		{
			for (size_t i = 0; i < node->v.element.attributes.length; ++i)
			{
				GumboAttribute *href = static_cast<GumboAttribute *>(node->v.element.attributes.data[i]);
				if (href && href->name == std::string("href"))
				{
					urls.push_back(href->value);
				}
			}
		}

		// Recursively search in child nodes
		for (size_t i = 0; i < node->v.element.children.length; ++i)
		{
			searchForLinks(static_cast<GumboNode *>(node->v.element.children.data[i]), urls);
		}
	}
}

size_t WriteCallback(void *contents, size_t size, size_t nmemb, void *userp)
{
	((std::string *)userp)->append((char *)contents, size * nmemb);
	return size * nmemb;
}

std::string fetchPage(const std::string &url)
{
	CURL *curl;
	CURLcode res;
	std::string readBuffer;

	curl = curl_easy_init();
	if (curl)
	{
		curl_easy_setopt(curl, CURLOPT_URL, url.c_str());
		curl_easy_setopt(curl, CURLOPT_WRITEFUNCTION, WriteCallback);
		curl_easy_setopt(curl, CURLOPT_WRITEDATA, &readBuffer);
		res = curl_easy_perform(curl);
		if (res != CURLE_OK)
		{
			std::cerr << "curl_easy_perform() failed: " << curl_easy_strerror(res) << std::endl;
		}
		curl_easy_cleanup(curl);
	}
	return readBuffer;
}
