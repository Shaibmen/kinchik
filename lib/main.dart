import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:image_picker/image_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:hive/hive.dart';

class Movie {
  String title;
  int year;
  String genre;
  Uint8List? imageBytes;

  Movie({
    required this.title,
    required this.year,
    required this.genre,
    this.imageBytes,
  });

  Map<String, dynamic> toMap() {
    return {
      'title': title,
      'year': year,
      'genre': genre,
      'imageBytes': imageBytes,
    };
  }

  factory Movie.fromMap(Map<String, dynamic> map) {
    return Movie(
      title: map['title'],
      year: map['year'],
      genre: map['genre'],
      imageBytes: map['imageBytes'],
    );
  }
}

class MovieAdapter extends TypeAdapter<Movie> {
  @override
  final int typeId = 0;

  @override
  Movie read(BinaryReader reader) {
    return Movie.fromMap(reader.readMap().cast<String, dynamic>());
  }

  @override
  void write(BinaryWriter writer, Movie obj) {
    writer.writeMap(obj.toMap());
  }
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Hive.initFlutter();
  Hive.registerAdapter(MovieAdapter());
  await Hive.openBox<Movie>('movies');
  runApp(MyApp());
}

class MyApp extends StatefulWidget {
  @override
  _MyAppState createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  bool _isDarkMode = false;
  late SharedPreferences _prefs;

  @override
  void initState() {
    super.initState();
    _loadTheme();
  }

  _loadTheme() async {
    _prefs = await SharedPreferences.getInstance();
    setState(() {
      _isDarkMode = _prefs.getBool('isDarkMode') ?? false;
    });
  }

  _toggleTheme() async {
    setState(() {
      _isDarkMode = !_isDarkMode;
    });
    await _prefs.setBool('isDarkMode', _isDarkMode);
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Мини Кинопоиск',
      theme: ThemeData.light(),
      darkTheme: ThemeData.dark(),
      themeMode: _isDarkMode ? ThemeMode.dark : ThemeMode.light,
      home: HomePage(
        onThemeToggle: _toggleTheme,
        isDarkMode: _isDarkMode,
      ),
    );
  }
}

class HomePage extends StatefulWidget {
  final VoidCallback onThemeToggle;
  final bool isDarkMode;

  HomePage({required this.onThemeToggle, required this.isDarkMode});

  @override
  _HomePageState createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  late Box<Movie> movieBox;

  @override
  void initState() {
    super.initState();
    movieBox = Hive.box<Movie>('movies');
  }

  Future<void> _deleteMovie(int key) async {
    await movieBox.delete(key);
  }

  void _navigateToAddScreen(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => AddEditScreen(
          onSave: (movie) async {
            await movieBox.add(movie);
          },
        ),
      ),
    );
  }

  void _navigateToEditScreen(BuildContext context, Movie movie, int key) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => AddEditScreen(
          movie: movie,
          keyIndex: key,
          onSave: (updatedMovie) async {
            await movieBox.put(key, updatedMovie);
          },
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Мои фильмы'),
        actions: [
          IconButton(
            icon: Icon(widget.isDarkMode ? Icons.light_mode : Icons.dark_mode),
            onPressed: widget.onThemeToggle,
          ),
        ],
      ),
      body: ValueListenableBuilder(
        valueListenable: movieBox.listenable(),
        builder: (context, Box<Movie> box, _) {
          if (box.isEmpty) {
            return Center(child: Text('Нет фильмов'));
          }
          return ListView.builder(
            itemCount: box.length,
            itemBuilder: (ctx, index) {
              final key = box.keyAt(index) as int;
              final movie = box.getAt(index)!;
              return ListTile(
                leading: movie.imageBytes != null
                    ? Image.memory(
                        movie.imageBytes!,
                        width: 50,
                        height: 50,
                        fit: BoxFit.cover,
                        errorBuilder: (context, error, stackTrace) =>
                            Container(width: 50, height: 50, color: Colors.grey, child: Icon(Icons.broken_image)),
                      )
                    : Container(width: 50, height: 50, color: Colors.grey, child: Icon(Icons.movie)),
                title: Text(movie.title),
                subtitle: Text('${movie.year} • ${movie.genre}'),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      icon: Icon(Icons.edit),
                      onPressed: () => _navigateToEditScreen(context, movie, key),
                    ),
                    IconButton(
                      icon: Icon(Icons.delete),
                      onPressed: () => _deleteMovie(key),
                    ),
                  ],
                ),
              );
            },
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        child: Icon(Icons.add),
        onPressed: () => _navigateToAddScreen(context),
      ),
    );
  }
}

class AddEditScreen extends StatefulWidget {
  final Movie? movie;
  final int? keyIndex;
  final Future<void> Function(Movie) onSave;

  AddEditScreen({this.movie, this.keyIndex, required this.onSave});

  @override
  _AddEditScreenState createState() => _AddEditScreenState();
}

class _AddEditScreenState extends State<AddEditScreen> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _titleController;
  late TextEditingController _yearController;
  late TextEditingController _genreController;
  Uint8List? _imageBytes;

  @override
  void initState() {
    super.initState();
    _titleController = TextEditingController(text: widget.movie?.title ?? '');
    _yearController = TextEditingController(text: widget.movie?.year.toString() ?? '');
    _genreController = TextEditingController(text: widget.movie?.genre ?? '');
    _imageBytes = widget.movie?.imageBytes;
  }

  @override
  void dispose() {
    _titleController.dispose();
    _yearController.dispose();
    _genreController.dispose();
    super.dispose();
  }

  Future<void> _pickImage() async {
    try {
      final picker = ImagePicker();
      final XFile? pickedFile = await picker.pickImage(source: ImageSource.gallery);
      if (pickedFile != null) {
        final bytes = await pickedFile.readAsBytes();
        setState(() {
          _imageBytes = bytes;
        });
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Ошибка выбора изображения $e')));
    }
  }

  Future<void> _save() async {
    if (_formKey.currentState!.validate()) {
      final title = _titleController.text;
      final year = int.parse(_yearController.text);
      final genre = _genreController.text;

      final movie = Movie(
        title: title,
        year: year,
        genre: genre,
        imageBytes: _imageBytes,
      );

      await widget.onSave(movie);
      Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.movie == null ? 'Добавить фильм' : 'Редактировать'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: ListView(
            children: [
              TextFormField(
                controller: _titleController,
                decoration: InputDecoration(labelText: 'Название'),
                validator: (value) => value!.isEmpty ? 'Введите название' : null,
              ),
              TextFormField(
                controller: _yearController,
                decoration: InputDecoration(labelText: 'Год выпуска'),
                keyboardType: TextInputType.number,
                validator: (value) {
                  if (value!.isEmpty) return 'Введите год';
                  if (int.tryParse(value) == null) return 'Введите число';
                  return null;
                },
              ),
              TextFormField(
                controller: _genreController,
                decoration: InputDecoration(labelText: 'Жанр'),
                validator: (value) => value!.isEmpty ? 'Введите жанр' : null,
              ),
              SizedBox(height: 20),
              GestureDetector(
                onTap: _pickImage,
                child: Container(
                  width: double.infinity,
                  height: 200,
                  decoration: BoxDecoration(
                    border: Border.all(color: Colors.grey),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: _imageBytes != null
                      ? Image.memory(_imageBytes!, fit: BoxFit.cover)
                      : Center(child: Text('Нажмите, чтобы выбрать изображение')),
                ),
              ),
              SizedBox(height: 20),
              ElevatedButton(
                onPressed: _save,
                child: Text('Сохранить'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}