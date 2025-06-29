import 'package:flutter/material.dart';
import 'package:xedmail/screen/inbox.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  String? searchQuery;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Home Page')),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            Column(
              children: [
                Text('xedMail', style: TextStyle(fontSize: 64)),
                SearchAnchor(
                  builder: (BuildContext context, SearchController controller) {
                    return SearchBar(
                      controller: controller,
                      padding: const WidgetStatePropertyAll<EdgeInsets>(
                        EdgeInsets.symmetric(horizontal: 16.0),
                      ),
                      onTap: () {
                        print("Opening search view");
                        // controller.openView();
                      },
                      onChanged: (query) {
                        print('Search query: $query');
                        setState(() {
                          print("Setting search query to: $query");
                          searchQuery = query;
                        });
                        // controller.openView(); // The controller is the suggestions view.
                      },
                      onSubmitted: (query) {
                        print("Searching");
                        // setState(() {
                        //   searchQuery = query;
                        // });
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => Inbox(searchQuery: query),
                          ),
                        );
                        // Navigate to search results page
                      },
                      leading: const Icon(Icons.search),
                    );
                  },
                  suggestionsBuilder:
                      (BuildContext context, SearchController controller) {
                        return List<ListTile>.generate(5, (int index) {
                          final String item = 'item_$index';
                          return ListTile(
                            title: Text(item),
                            onTap: () {
                              controller.closeView(item);
                            },
                          );
                        });
                      },
                ),
                SizedBox(height: 24),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        minimumSize: Size(150, 50),
                      ),
                      onPressed: () {
                        print("Search mail");
                      },
                      child: Text("Search Mail"),
                    ),
                    SizedBox(width: 16),
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        minimumSize: Size(150, 50),
                      ),
                      onPressed: () {
                        print("I'm Feeling Lucky");
                      },
                      child: Text("I'm Feeling Lucky"),
                    ),
                  ],
                ),
              ],
            ),
            Column(),
            Column(),
          ],
        ),
      ),
    );
  }
}
