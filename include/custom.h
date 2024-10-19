#ifndef CUSTOM_H
#define CUSTOM_H

#include <vector>
#include <string>
#include <gumbo.h>

void searchForLinks(GumboNode *node, std::vector<std::string> &urls);
size_t WriteCallback(void *contents, size_t size, size_t nmemb, void *userp);
std::string fetchPage(const std::string &url);

#endif // CUSTOM_H
