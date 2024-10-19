#include <iostream>
#include <vector>
#include <string>
#include <curl/curl.h>
#include <gumbo.h>
#include "../include/custom.h"

int main()
{
	std::string url = "https://www.beardeddonkey.com/"; // Replace with your target URL
	std::string html = fetchPage(url);

	if (html.empty())
	{
		std::cerr << "Failed to fetch HTML or received empty response." << std::endl;
		return 1;
	}

	GumboOutput *output = gumbo_parse(html.c_str());
	if (!output)
	{
		std::cerr << "Failed to parse HTML." << std::endl;
		return 1;
	}
	std::vector<std::string> urls;
	searchForLinks(output->root, urls);
	gumbo_destroy_output(&kGumboDefaultOptions, output);

	for (const auto &link : urls)
	{
		std::cout << link << std::endl;
	}

	return 0;
}
