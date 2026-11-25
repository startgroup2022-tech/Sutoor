import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:pdfx/pdfx.dart';
import 'package:url_launcher/url_launcher.dart';
import 'api.dart';

const green = Color(0xFF064833);
const deep = Color(0xFF053B2B);
const gold = Color(0xFFAD7C22);
const paleGold = Color(0xFFEFD79D);
const cream = Color(0xFFFAF7EF);
const ink = Color(0xFF182A25);
const muted = Color(0xFF6B756F);
const edge = Color(0xFFEAE2D3);

String val(Map<String, dynamic> m, String key, [String fallback = '']) =>
    m[key]?.toString() ?? fallback;
int numId(Map<String, dynamic> m) => int.tryParse(val(m, 'id')) ?? 0;
bool truth(dynamic v) => v == true || v == 1 || v == '1';
Color coverColor(Map<String, dynamic> book) {
  final c = val(book, 'color', '#176653');
  return RegExp(r'^#[0-9a-fA-F]{6}$').hasMatch(c)
      ? Color(int.parse('FF${c.substring(1)}', radix: 16)) : green;
}
void notify(BuildContext context, String message) {
  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message),
      behavior: SnackBarBehavior.floating, backgroundColor:deep));
}

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const SutoorApp());
}

class SutoorApp extends StatefulWidget {
  const SutoorApp({super.key});
  @override State<SutoorApp> createState() => _SutoorAppState();
}
class _SutoorAppState extends State<SutoorApp> {
  final api = SutoorApi();
  bool ready = false;
  bool signed = false;
  int tab = 0;
  String categoryFilter = '';
  @override void initState() { super.initState(); _initialize(); }
  Future<void> _initialize() async {
    await api.restore();
    if (api.loggedIn) {
      // An offline start or temporary server outage must not erase a valid
      // session. Only a confirmed HTTP 401 invalidates the saved token.
      try {
        await api.me();
      } on ApiException catch (error) {
        if (error.statusCode == 401) await api.logout();
      }
    }
    if (mounted) setState(() { ready = true; signed = api.loggedIn; });
  }
  void _signedIn() { setState(() { signed = true; tab = 4; }); }
  void _signedOut() { setState(() { signed = false; tab = 0; }); }
  void _explore([String category = '']) {
    setState(() { categoryFilter = category; tab = 1; });
  }
  @override void dispose() { api.dispose(); super.dispose(); }
  @override Widget build(BuildContext context) {
    final textTheme = GoogleFonts.tajawalTextTheme();
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'سطور | مكتبة رقمية',
      locale: const Locale('ar'),
      supportedLocales: const [Locale('ar')],
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      theme: ThemeData(
        useMaterial3: true, scaffoldBackgroundColor: const Color(0xFFFCFAF6),
        textTheme: textTheme.apply(bodyColor: ink, displayColor: ink),
        colorScheme: ColorScheme.fromSeed(seedColor: green, primary: green,
            secondary: gold, surface: const Color(0xFFFCFAF6)),
        appBarTheme: AppBarTheme(backgroundColor: Colors.white,
            foregroundColor: green, elevation: 0, centerTitle: false,
            surfaceTintColor: Colors.transparent,
            titleTextStyle: GoogleFonts.tajawal(color:green,fontSize:20,fontWeight:FontWeight.w800)),
        inputDecorationTheme: InputDecorationTheme(
          filled: true, fillColor: const Color(0xFFFDFCF9),
          contentPadding: const EdgeInsets.symmetric(horizontal:16, vertical:17),
          border: OutlineInputBorder(borderRadius:BorderRadius.circular(13),
              borderSide:const BorderSide(color:edge)),
          enabledBorder: OutlineInputBorder(borderRadius:BorderRadius.circular(13),
              borderSide:const BorderSide(color:edge)),
          focusedBorder: OutlineInputBorder(borderRadius:BorderRadius.circular(13),
              borderSide:const BorderSide(color:green,width:1.6)),
        ),
        filledButtonTheme: FilledButtonThemeData(style:FilledButton.styleFrom(
          backgroundColor: green, foregroundColor: Colors.white,
          minimumSize:const Size.fromHeight(53),
          textStyle:GoogleFonts.tajawal(fontSize:16,fontWeight:FontWeight.w800),
          shape:RoundedRectangleBorder(borderRadius:BorderRadius.circular(13)))),
        cardTheme: CardThemeData(color:Colors.white, elevation:0,
            shape:RoundedRectangleBorder(borderRadius:BorderRadius.circular(18),
                side:const BorderSide(color:edge))),
        navigationBarTheme: NavigationBarThemeData(
          backgroundColor: Colors.white, indicatorColor: const Color(0xFFE6EEE8),
          labelTextStyle: WidgetStatePropertyAll(GoogleFonts.tajawal(
              fontSize: 11, fontWeight: FontWeight.w700, color: deep)),
          height:72),
      ),
      builder:(context, child) => Directionality(
          textDirection:TextDirection.rtl,child:child ?? const SizedBox.shrink()),
      home: !ready ? const SplashScreen() : Scaffold(
        appBar: AppBar(toolbarHeight:73,
          title:Row(children:[const BrandMark(size:46), const SizedBox(width:11),
            Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
              Text('سطور',style:GoogleFonts.tajawal(color:green,fontSize:27,
                  fontWeight:FontWeight.w900,height:1.05)),
              Text('مكتبة رقمية',style:GoogleFonts.tajawal(color:gold,fontSize:12,
                  fontWeight:FontWeight.w700)),
            ]), const Spacer(),
            if (!signed) IconButton(tooltip:'تسجيل الدخول',onPressed:()=>setState(()=>tab=4),
                icon:const Icon(Icons.account_circle_outlined,color:green,size:27)),
          ]),
          bottom:PreferredSize(preferredSize:const Size.fromHeight(1),
              child:Container(height:1,color:edge))),
        body: IndexedStack(index:tab,children:[
          HomePage(api:api,onExplore:_explore),
          BooksPage(key:ValueKey(categoryFilter),api:api,category:categoryFilter),
          MyLibraryPage(api:api,signed:signed,onLogin:()=>setState(()=>tab=4)),
          PlansPage(api:api,onLogin:()=>setState(()=>tab=4)),
          AccountPage(api:api,signed:signed,onLogin:_signedIn,onLogout:_signedOut),
        ]),
        bottomNavigationBar: NavigationBar(selectedIndex:tab,
          onDestinationSelected:(n)=>setState(()=>tab=n),
          destinations:const [
            NavigationDestination(icon:Icon(Icons.home_outlined),selectedIcon:Icon(Icons.home),label:'الرئيسية'),
            NavigationDestination(icon:Icon(Icons.menu_book_outlined),selectedIcon:Icon(Icons.menu_book),label:'الكتب'),
            NavigationDestination(icon:Icon(Icons.bookmark_outline),selectedIcon:Icon(Icons.bookmark),label:'مكتبتي'),
            NavigationDestination(icon:Icon(Icons.workspace_premium_outlined),selectedIcon:Icon(Icons.workspace_premium),label:'الباقات'),
            NavigationDestination(icon:Icon(Icons.person_outline),selectedIcon:Icon(Icons.person),label:'حسابي'),
          ]),
      ),
    );
  }
}

class BrandMark extends StatelessWidget {
  const BrandMark({super.key,this.size=78});
  final double size;
  @override Widget build(BuildContext context) => Container(
    width:size,height:size,padding:const EdgeInsets.all(3),
    decoration:BoxDecoration(shape:BoxShape.circle,
      border:Border.all(color:gold,width:1.5),color:Colors.white),
    child:ClipOval(child:Image.asset('assets/images/brand.jpg',fit:BoxFit.cover)),
  );
}
class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});
  @override State<SplashScreen> createState()=>_SplashScreenState();
}
class _SplashScreenState extends State<SplashScreen> with SingleTickerProviderStateMixin {
  late final AnimationController controller;
  @override void initState() {
    super.initState();
    controller=AnimationController(vsync:this,duration:const Duration(milliseconds:1250))..forward();
  }
  @override void dispose(){controller.dispose();super.dispose();}
  @override Widget build(BuildContext context)=>Scaffold(body:Container(
    decoration:const BoxDecoration(gradient:LinearGradient(
      begin:Alignment.topRight,end:Alignment.bottomLeft,
      colors:[Color(0xFF064833),Color(0xFF012B20)])),
    child:SafeArea(child:Center(child:FadeTransition(opacity:controller,
      child:ScaleTransition(scale:Tween<double>(begin:.83,end:1).animate(
          CurvedAnimation(parent:controller,curve:Curves.easeOutBack)),
        child:Column(mainAxisSize:MainAxisSize.min,children:[
          const BrandMark(size:124),const SizedBox(height:25),
          Text('سطور',style:GoogleFonts.tajawal(color:Colors.white,fontSize:53,
            fontWeight:FontWeight.w900)),
          Text('مكتبة رقمية',style:GoogleFonts.tajawal(color:paleGold,fontSize:19,
            fontWeight:FontWeight.w700)),
          const SizedBox(height:45),const SizedBox(width:28,height:28,
            child:CircularProgressIndicator(color:paleGold,strokeWidth:2)),
          const SizedBox(height:18),Text('عالم من المعرفة بين يديك',
            style:GoogleFonts.tajawal(color:Colors.white70,fontSize:13)),
        ]))))),
  ));
}

class SectionTitle extends StatelessWidget {
  const SectionTitle(this.title,{super.key,this.subtitle,this.action,this.onAction});
  final String title;
  final String? subtitle, action;
  final VoidCallback? onAction;
  @override Widget build(BuildContext context) => Padding(
    padding:const EdgeInsets.fromLTRB(18,23,18,11),
    child:Row(crossAxisAlignment:CrossAxisAlignment.center,children:[
      Container(width:4,height:29,decoration:BoxDecoration(color:gold,borderRadius:BorderRadius.circular(4))),
      const SizedBox(width:9),Expanded(child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
        Text(title,style:GoogleFonts.tajawal(fontSize:21,color:green,fontWeight:FontWeight.w900)),
        if(subtitle!=null)Text(subtitle!,style:const TextStyle(fontSize:12,color:muted)),
      ])),
      if(action!=null)TextButton(onPressed:onAction,child:Text(action!,
          style:const TextStyle(fontWeight:FontWeight.w800,color:gold))),
    ]));
}
class AsyncList extends StatelessWidget {
  const AsyncList({super.key,required this.future,required this.builder,this.onRetry});
  final Future<List<Map<String,dynamic>>> future;
  final Widget Function(List<Map<String,dynamic>>) builder;
  final VoidCallback? onRetry;
  @override Widget build(BuildContext context)=>FutureBuilder<List<Map<String,dynamic>>>(
    future:future,builder:(context,snapshot){
      if(!snapshot.hasData && !snapshot.hasError) return const Padding(
        padding:EdgeInsets.symmetric(vertical:45),child:Center(child:CircularProgressIndicator()));
      if(snapshot.hasError) return Padding(padding:const EdgeInsets.all(24),child:Column(
        mainAxisSize:MainAxisSize.min,children:[
          const Icon(Icons.cloud_off_outlined,color:gold,size:35),
          const SizedBox(height:12),Text('${snapshot.error}',textAlign:TextAlign.center),
          if(onRetry!=null)TextButton(onPressed:onRetry,child:const Text('إعادة المحاولة')),
        ]));
      return builder(snapshot.data ?? []);
    });
}
class BookCover extends StatelessWidget {
  const BookCover({super.key,required this.book,this.width=126});
  final Map<String,dynamic> book;
  final double width;
  @override Widget build(BuildContext context) {
    final title=val(book,'title');
    final cover=val(book,'cover');
    final url=RegExp(r'^assets/img/covers/[a-zA-Z0-9_.-]+$').hasMatch(cover)
        ? 'https://sutoor.it.com/$cover' : null;
    return Container(width:width,height:width*1.43,clipBehavior:Clip.antiAlias,
      decoration:BoxDecoration(borderRadius:BorderRadius.circular(8),
        border:Border.all(color:const Color(0x22000000)),
        boxShadow:const [BoxShadow(color:Color(0x1B000000),blurRadius:15,offset:Offset(0,6))],
        gradient:LinearGradient(begin:Alignment.topRight,end:Alignment.bottomLeft,
          colors:[coverColor(book),Color.lerp(coverColor(book),Colors.black,.29)!])),
      child:url!=null?Image.network(url,fit:BoxFit.cover,
        errorBuilder:(_,error,stack)=>_coverText(title)):_coverText(title));
  }
  Widget _coverText(String title)=>Stack(children:[
    Positioned.fill(child:Padding(padding:const EdgeInsets.all(9),child:Container(
      decoration:BoxDecoration(border:Border.all(color:const Color(0x77EFD79D)),
          borderRadius:BorderRadius.circular(3))))),
    Padding(padding:const EdgeInsets.symmetric(horizontal:10,vertical:12),
      child:Column(mainAxisAlignment:MainAxisAlignment.center,children:[
        const Icon(Icons.auto_stories_rounded,size:31,color:paleGold),
        const SizedBox(height:10),Text(title,textAlign:TextAlign.center,maxLines:4,
          style:GoogleFonts.tajawal(color:Colors.white,fontWeight:FontWeight.w900,fontSize:16,height:1.3)),
        const SizedBox(height:12),Container(height:1,width:43,color:paleGold),
        const SizedBox(height:10),Text(val(book,'author'),maxLines:2,textAlign:TextAlign.center,
          style:const TextStyle(fontSize:11,color:Color(0xFFF2E2C4))),
      ])),
  ]);
}
class BookTile extends StatelessWidget {
  const BookTile({super.key,required this.book,required this.api});
  final Map<String,dynamic> book;
  final SutoorApi api;
  @override Widget build(BuildContext context)=>InkWell(
    borderRadius:BorderRadius.circular(15),
    onTap:()=>Navigator.push(context,MaterialPageRoute(builder:(_)=>BookDetails(api:api,book:book))),
    child:Container(padding:const EdgeInsets.fromLTRB(9,12,9,9),
      decoration:BoxDecoration(color:Colors.white,borderRadius:BorderRadius.circular(15),
        border:Border.all(color:edge)),
      child:Column(children:[
        Expanded(child:LayoutBuilder(builder:(context,limits)=>BookCover(
          book:book,width:limits.maxWidth.clamp(90.0,150.0).toDouble()))),
        const SizedBox(height:8),Text(val(book,'title'),textAlign:TextAlign.center,
          maxLines:2,overflow:TextOverflow.ellipsis,
          style:GoogleFonts.tajawal(fontWeight:FontWeight.w800,fontSize:14,height:1.2)),
        const SizedBox(height:2),Text(val(book,'author'),maxLines:1,overflow:TextOverflow.ellipsis,
          style:const TextStyle(fontSize:11,color:muted)),
        const SizedBox(height:4),Row(mainAxisAlignment:MainAxisAlignment.center,children:[
          const Icon(Icons.star_rounded,color:gold,size:14),
          Text(' ${val(book,'rating','—')}',style:const TextStyle(fontSize:11,color:gold)),
        ]),
      ])));
}
class BooksGrid extends StatelessWidget {
  const BooksGrid({super.key,required this.books,required this.api});
  final List<Map<String,dynamic>> books;
  final SutoorApi api;
  @override Widget build(BuildContext context) => LayoutBuilder(builder:(context,limits) {
    final count=limits.maxWidth>=600?4:2;
    return GridView.builder(shrinkWrap:true,physics:const NeverScrollableScrollPhysics(),
      padding:const EdgeInsets.symmetric(horizontal:16,vertical:7),
      itemCount:books.length,
      gridDelegate:SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount:count,
        childAspectRatio: count == 2 ? 0.58 : 0.63,mainAxisSpacing:13,crossAxisSpacing:13),
      itemBuilder:(context,i)=>BookTile(book:books[i],api:api));
  });
}

class HomePage extends StatefulWidget {
  const HomePage({super.key,required this.api,required this.onExplore});
  final SutoorApi api;
  final void Function([String]) onExplore;
  @override State<HomePage> createState()=>_HomePageState();
}
class _HomePageState extends State<HomePage> {
  late Future<List<Map<String,dynamic>>> books,categories;
  @override void initState(){super.initState();_load();}
  void _load(){books=widget.api.list('/books');categories=widget.api.list('/categories');}
  Future<void> _refresh()async {setState(_load);await Future.wait([books,categories]);}
  @override Widget build(BuildContext context)=>RefreshIndicator(onRefresh:_refresh,
    child:ListView(children:[
      Container(margin:const EdgeInsets.fromLTRB(14,15,14,6),
        decoration:BoxDecoration(borderRadius:BorderRadius.circular(20),
          color:const Color(0xFFF3EBDD),border:Border.all(color:edge)),clipBehavior:Clip.antiAlias,
        child:Column(children:[
          Padding(padding:const EdgeInsets.fromLTRB(20,25,20,19),child:Column(children:[
            const BrandMark(size:72),const SizedBox(height:13),
            Text('رحلتك في عالم الكتب تبدأ هنا',textAlign:TextAlign.center,
              style:GoogleFonts.tajawal(color:green,fontSize:26,fontWeight:FontWeight.w900,height:1.17)),
            const SizedBox(height:9),Text('مكتبة واحدة، عوالم بلا حدود',
              style:GoogleFonts.tajawal(color:gold,fontSize:18,fontWeight:FontWeight.w800)),
            const SizedBox(height:9),const Text('استكشف المعرفة وأضف إلى يومك صفحات تستحق القراءة',
                textAlign:TextAlign.center,style:TextStyle(fontSize:13,color:muted)),
            const SizedBox(height:18),FilledButton.icon(onPressed:()=>widget.onExplore(),
              icon:const Icon(Icons.menu_book),label:const Text('استكشف مكتبتنا')),
          ])),
          SizedBox(height:155,width:double.infinity,child:Image.asset(
              'assets/images/hero-library.jpg',fit:BoxFit.cover)),
        ])),
      SectionTitle('تصفّح حسب التصنيف',subtitle:'اكتشف ما يناسب شغفك'),
      SizedBox(height:105,child:AsyncList(future:categories,onRetry:()=>setState(_load),
        builder:(items)=>ListView.separated(scrollDirection:Axis.horizontal,
          padding:const EdgeInsets.symmetric(horizontal:16),itemCount:items.length,
          separatorBuilder:(_,index)=>const SizedBox(width:10),
          itemBuilder:(context,i)=>InkWell(onTap:()=>widget.onExplore(val(items[i],'name')),
            child:Container(width:119,padding:const EdgeInsets.all(11),
              decoration:BoxDecoration(color:Colors.white,borderRadius:BorderRadius.circular(14),
                border:Border.all(color:edge)),
              child:Column(mainAxisAlignment:MainAxisAlignment.center,children:[
                const Icon(Icons.local_library_outlined,color:gold,size:27),
                const SizedBox(height:7),Text(val(items[i],'name'),textAlign:TextAlign.center,
                  maxLines:2,style:const TextStyle(fontSize:12,fontWeight:FontWeight.w800)),
              ])))),
      )),
      Container(margin:const EdgeInsets.fromLTRB(16,23,16,3),padding:const EdgeInsets.all(20),
        decoration:BoxDecoration(borderRadius:BorderRadius.circular(18),
          gradient:const LinearGradient(colors:[green,deep])),
        child:Column(children:[
          Text('اقرأ أكثر، اكتشف أكثر',textAlign:TextAlign.center,
            style:GoogleFonts.tajawal(color:paleGold,fontSize:24,fontWeight:FontWeight.w900)),
          const SizedBox(height:6),const Text('كتب مختارة، باقات مرنة، ومكتبتك معك أينما كنت',
              textAlign:TextAlign.center,style:TextStyle(color:Colors.white)),
          const SizedBox(height:15),const Row(mainAxisAlignment:MainAxisAlignment.spaceEvenly,children:[
            _PromoPoint(Icons.auto_stories_outlined,'كتب متنوعة'),
            _PromoPoint(Icons.verified_user_outlined,'قراءة آمنة'),
            _PromoPoint(Icons.devices_outlined,'تجربة مريحة'),
          ]),
        ])),
      SectionTitle('مختارات سطور',subtitle:'من الكتب المنشورة على الموقع',
        action:'عرض الكل',onAction:()=>widget.onExplore()),
      AsyncList(future:books,onRetry:()=>setState(_load),builder:(items)=>items.isEmpty
        ?const EmptyState('لا توجد كتب منشورة حالياً',icon:Icons.menu_book_outlined)
        :BooksGrid(books:items.where((b)=>truth(b['is_featured'])).isNotEmpty
            ?items.where((b)=>truth(b['is_featured'])).take(6).toList()
            :items.take(6).toList(),api:widget.api)),
      const SizedBox(height:25),
    ]));
}
class _PromoPoint extends StatelessWidget {
  const _PromoPoint(this.icon,this.label);
  final IconData icon;final String label;
  @override Widget build(BuildContext context)=>Column(children:[
    Icon(icon,color:paleGold,size:26),const SizedBox(height:6),
    Text(label,style:const TextStyle(color:Colors.white,fontSize:11,fontWeight:FontWeight.w800)),
  ]);
}
class EmptyState extends StatelessWidget {
  const EmptyState(this.message,{super.key,this.icon=Icons.menu_book_outlined,this.action,this.onAction});
  final String message;final IconData icon;final String? action;final VoidCallback? onAction;
  @override Widget build(BuildContext context)=>Padding(padding:const EdgeInsets.all(32),
    child:Column(mainAxisSize:MainAxisSize.min,children:[
      Icon(icon,size:60,color:gold),const SizedBox(height:14),
      Text(message,textAlign:TextAlign.center,style:const TextStyle(fontSize:15,color:muted)),
      if(action!=null)...[const SizedBox(height:15),FilledButton(onPressed:onAction,child:Text(action!))],
    ]));
}

class BooksPage extends StatefulWidget {
  const BooksPage({super.key,required this.api,this.category=''});
  final SutoorApi api;final String category;
  @override State<BooksPage> createState()=>_BooksPageState();
}
class _BooksPageState extends State<BooksPage> {
  late Future<List<Map<String,dynamic>>> books;
  late Future<List<Map<String,dynamic>>> categories;
  String query='',category='';
  @override void initState(){super.initState();category=widget.category;_load();}
  void _load(){books=widget.api.list('/books');categories=widget.api.list('/categories');}
  Future<void> _refresh()async{setState(_load);await Future.wait([books,categories]);}
  @override Widget build(BuildContext context)=>Column(children:[
    const SectionTitle('مكتبة سطور',subtitle:'ابحث عن كتابك المفضل واكتشف جديدنا'),
    Padding(padding:const EdgeInsets.symmetric(horizontal:16),child:TextField(
      onChanged:(v)=>setState(()=>query=v.trim().toLowerCase()),
      decoration:const InputDecoration(prefixIcon:Icon(Icons.search,color:green),
        hintText:'عنوان الكتاب، المؤلف أو التصنيف'))),
    const SizedBox(height:10),SizedBox(height:48,child:AsyncList(future:categories,
      builder:(items)=>ListView(scrollDirection:Axis.horizontal,
        padding:const EdgeInsets.symmetric(horizontal:16),children:[
          _categoryChip('جميع الكتب',''),
          for(final item in items)_categoryChip(val(item,'name'),val(item,'name')),
        ]))),
    Expanded(child:RefreshIndicator(onRefresh:_refresh,
      child:AsyncList(future:books,onRetry:()=>setState(_load),builder:(items){
        final filtered=items.where((b){
          final matchesCategory=category.isEmpty || val(b,'category')==category;
          final matchesQuery=[val(b,'title'),val(b,'author'),val(b,'category')]
              .any((s)=>s.toLowerCase().contains(query));
          return matchesCategory && matchesQuery;
        }).toList();
        if(filtered.isEmpty)return ListView(children:const [EmptyState('لم نعثر على كتب مطابقة')]);
        return ListView(children:[const SizedBox(height:14),BooksGrid(books:filtered,api:widget.api),
          const SizedBox(height:24)]);
      }))),
  ]);
  Widget _categoryChip(String label,String value)=>Padding(
    padding:const EdgeInsets.only(left:8),
    child:ChoiceChip(label:Text(label),selected:category==value,
      selectedColor:const Color(0xFFE8EFE9),side:const BorderSide(color:edge),
      onSelected:(_)=>setState(()=>category=value)));
}

class MyLibraryPage extends StatefulWidget {
  const MyLibraryPage({super.key,required this.api,required this.signed,required this.onLogin});
  final SutoorApi api;final bool signed;final VoidCallback onLogin;
  @override State<MyLibraryPage> createState()=>_MyLibraryPageState();
}
class _MyLibraryPageState extends State<MyLibraryPage>{
  Future<List<Map<String,dynamic>>>? library;
  @override void initState(){super.initState();_load();}
  void _load(){library=widget.signed?widget.api.myLibrary():null;}
  @override void didUpdateWidget(covariant MyLibraryPage oldWidget){
    super.didUpdateWidget(oldWidget);
    if(oldWidget.signed!=widget.signed)_load();
  }
  @override Widget build(BuildContext context){
    if(!widget.signed)return EmptyState('سجّل دخولك لمشاهدة كتبك المتاحة حسب اشتراكك',
      icon:Icons.bookmarks_outlined,action:'تسجيل الدخول',onAction:widget.onLogin);
    return RefreshIndicator(onRefresh:()async{
      setState(_load);await library;
    },child:ListView(children:[
      const SectionTitle('مكتبتي الشخصية',subtitle:'الكتب المتاحة لحسابك على سطور'),
      AsyncList(future:library!,onRetry:()=>setState(_load),builder:(items)=>items.isEmpty
        ?const EmptyState('لا توجد كتب متاحة حالياً. تصفح الكتب أو راجع اشتراكك.')
        :BooksGrid(books:items,api:widget.api)),
    ]));
  }
}

class BookDetails extends StatefulWidget {
  const BookDetails({super.key,required this.api,required this.book});
  final SutoorApi api;final Map<String,dynamic> book;
  @override State<BookDetails> createState()=>_BookDetailsState();
}
class _BookDetailsState extends State<BookDetails>{bool busy=false;
  Future<void> _read() async {
    if(!widget.api.loggedIn){notify(context,'سجّل دخولك أولاً لتتمكن من القراءة');return;}
    setState(()=>busy=true);
    try {
      final access=await widget.api.access(numId(widget.book));
      if(!mounted)return;
      if(!truth(access['can_read'])){notify(context,'هذا الكتاب غير متاح ضمن صلاحيات اشتراكك');return;}
      await Navigator.push(context,MaterialPageRoute(builder:(_)=>ReaderPage(
        api:widget.api,book:widget.book)));
    }catch(e){if(mounted)notify(context,'$e');}
    finally {if(mounted)setState(()=>busy=false);}
  }
  @override Widget build(BuildContext context){final b=widget.book;
    return Scaffold(appBar:AppBar(title:const Text('تفاصيل الكتاب')),
      body:ListView(padding:const EdgeInsets.all(22),children:[
        Center(child:BookCover(book:b,width:188)),const SizedBox(height:24),
        Text(val(b,'title'),textAlign:TextAlign.center,
          style:GoogleFonts.tajawal(color:green,fontWeight:FontWeight.w900,fontSize:29)),
        Text('تأليف: ${val(b,'author')}',textAlign:TextAlign.center,
          style:const TextStyle(color:gold,fontSize:16)),
        const SizedBox(height:17),Wrap(alignment:WrapAlignment.center,spacing:8,runSpacing:7,children:[
          Chip(label:Text(val(b,'category','كتاب إلكتروني'))),
          Chip(label:Text(truth(b['is_free'])?'مجاني':'حسب الاشتراك')),
          Chip(avatar:const Icon(Icons.star,color:gold,size:17),label:Text(val(b,'rating','—'))),
        ]),const SizedBox(height:20),
        const Text('نبذة عن الكتاب',style:TextStyle(color:green,fontSize:20,fontWeight:FontWeight.w900)),
        const SizedBox(height:8),Text(val(b,'description','لا يتوفر وصف لهذا الكتاب حالياً.'),
          style:const TextStyle(color:muted,fontSize:15,height:1.7)),
        const SizedBox(height:24),FilledButton.icon(onPressed:busy?null:_read,
          icon:busy?const SizedBox(height:17,width:17,child:CircularProgressIndicator(
                strokeWidth:2,color:Colors.white)):const Icon(Icons.chrome_reader_mode_outlined),
          label:Text(busy?'جاري التحقق من الاشتراك':'ابدأ القراءة')),
        const SizedBox(height:12),const Center(child:Text('تُحدَّد صلاحية القراءة من خادم سطور',
            style:TextStyle(color:muted,fontSize:12))),
      ]));
  }
}
class ReaderPage extends StatefulWidget {
  const ReaderPage({super.key,required this.api,required this.book});
  final SutoorApi api;final Map<String,dynamic> book;
  @override State<ReaderPage> createState()=>_ReaderPageState();
}
class _ReaderPageState extends State<ReaderPage>{
  PdfControllerPinch? pdf;
  String? error;
  bool loading=true;
  @override void initState(){super.initState();_open();}
  Future<void> _open()async{
    try {
      final bytes=await widget.api.bookPdf(numId(widget.book));
      if(!mounted)return;
      setState((){pdf=PdfControllerPinch(document:PdfDocument.openData(bytes));loading=false;});
    }catch(e){if(mounted)setState((){error='$e';loading=false;});}
  }
  @override void dispose(){pdf?.dispose();super.dispose();}
  @override Widget build(BuildContext context)=>Scaffold(
    backgroundColor:cream,appBar:AppBar(title:Text(val(widget.book,'title'))),
    body:loading?const Center(child:CircularProgressIndicator()):
      error!=null?EmptyState(error!,icon:Icons.picture_as_pdf_outlined,
        action:'إعادة المحاولة',onAction:(){setState((){error=null;loading=true;});_open();}):
      PdfViewPinch(controller:pdf!),
  );
}

class PlansPage extends StatefulWidget {
  const PlansPage({super.key,required this.api,required this.onLogin});
  final SutoorApi api;final VoidCallback onLogin;
  @override State<PlansPage> createState()=>_PlansPageState();
}
class _PlansPageState extends State<PlansPage>{
  late Future<List<Map<String,dynamic>>> plans;
  @override void initState(){super.initState();plans=widget.api.list('/plans');}
  Future<void> _order(Map<String,dynamic> plan)async{
    if(!widget.api.loggedIn){widget.onLogin();return;}
    try{
      final methods=await widget.api.list('/payment-methods');
      if(!mounted)return;
      if(methods.isEmpty){notify(context,'لا تتوفر وسائل دفع حالياً');return;}
      await showModalBottomSheet<void>(context:context,isScrollControlled:true,
        showDragHandle:true,builder:(ctx)=>SafeArea(child:Padding(
          padding:EdgeInsets.fromLTRB(20,14,20,MediaQuery.viewInsetsOf(ctx).bottom+25),
          child:Column(mainAxisSize:MainAxisSize.min,crossAxisAlignment:CrossAxisAlignment.stretch,children:[
            Text('طريقة الدفع',style:GoogleFonts.tajawal(fontSize:22,fontWeight:FontWeight.w900,color:green)),
            Text('الباقة: ${val(plan,'title')}',style:const TextStyle(color:muted)),
            const SizedBox(height:15),
            for(final method in methods)Card(child:ListTile(
              leading:const Icon(Icons.account_balance_wallet_outlined,color:gold),
              title:Text(val(method,'title'),style:const TextStyle(fontWeight:FontWeight.w800)),
              subtitle:Text(val(method,'instructions'),maxLines:3),
              trailing:const Icon(Icons.chevron_left,color:green),
              onTap:()async{
                Navigator.pop(ctx);
                try {
                  final o=await widget.api.order(numId(plan),numId(method));
                  if(!mounted)return;
                  notify(context,'تم إنشاء الطلب رقم #${val(o,'id')} وهو بانتظار مراجعة الإدارة');
                  final link=val(o,'whatsapp_url');
                  final uri=Uri.tryParse(link);
                  if(uri!=null&&uri.host=='wa.me'&&uri.scheme=='https'){
                    await launchUrl(uri,mode:LaunchMode.externalApplication);
                  }
                }catch(e){if(mounted)notify(context,'$e');}
              },
            )),
          ]))));
    }catch(e){if(mounted)notify(context,'$e');}
  }
  @override Widget build(BuildContext context)=>ListView(children:[
    const SectionTitle('باقات الاشتراك',subtitle:'اختر الباقة المناسبة وابدأ رحلتك'),
    Container(margin:const EdgeInsets.fromLTRB(16,2,16,20),padding:const EdgeInsets.all(20),
      decoration:BoxDecoration(color:deep,borderRadius:BorderRadius.circular(18)),
      child:const Row(children:[Icon(Icons.workspace_premium_outlined,color:paleGold,size:36),
        SizedBox(width:13),Expanded(child:Text('مكتبتك الرقمية معك في كل مكان',
            style:TextStyle(color:Colors.white,fontSize:17,fontWeight:FontWeight.w800)))])),
    AsyncList(future:plans,onRetry:()=>setState(()=>plans=widget.api.list('/plans')),
      builder:(items)=>items.isEmpty?const EmptyState('لا توجد باقات متاحة حالياً'):
        Column(children:items.map((p)=>Container(margin:const EdgeInsets.fromLTRB(16,0,16,15),
          child:Card(child:Padding(padding:const EdgeInsets.all(22),child:Column(
            crossAxisAlignment:CrossAxisAlignment.start,children:[
              Text(val(p,'title'),style:GoogleFonts.tajawal(color:green,fontSize:24,fontWeight:FontWeight.w900)),
              const SizedBox(height:8),Row(crossAxisAlignment:CrossAxisAlignment.end,children:[
                Text(val(p,'price_bhd','0'),style:GoogleFonts.tajawal(
                    color:gold,fontSize:35,fontWeight:FontWeight.w900)),
                const Padding(padding:EdgeInsets.only(bottom:8,right:6),
                    child:Text('د.ب',style:TextStyle(color:muted))),
              ]),Text('المدة: ${val(p,'duration_days')} يوم',style:const TextStyle(color:muted)),
              const Divider(height:23,color:edge),
              Text(val(p,'description'),style:const TextStyle(height:1.6)),
              const SizedBox(height:17),FilledButton(onPressed:()=>_order(p),
                child:const Text('اشترك الآن')),
            ]))))).toList())),
    const SizedBox(height:20),
  ]);
}

class AccountPage extends StatefulWidget {
  const AccountPage({super.key,required this.api,required this.signed,
      required this.onLogin,required this.onLogout});
  final SutoorApi api;final bool signed;
  final VoidCallback onLogin,onLogout;
  @override State<AccountPage> createState()=>_AccountPageState();
}
class _AccountPageState extends State<AccountPage>{
  final formKey=GlobalKey<FormState>();
  final name=TextEditingController();
  final email=TextEditingController();
  final password=TextEditingController();
  final confirmation=TextEditingController();
  bool register=false,busy=false,showPassword=false,accepted=false;
  Future<Map<String,dynamic>>? profile;
  Future<List<Map<String,dynamic>>>? orders,subs;
  @override void initState(){super.initState();_loadProfile();}
  void _loadProfile(){if(widget.signed){profile=widget.api.me();orders=widget.api.orders();subs=widget.api.subscriptions();}}
  @override void didUpdateWidget(covariant AccountPage oldWidget){super.didUpdateWidget(oldWidget);
    if(oldWidget.signed!=widget.signed)_loadProfile();}
  @override void dispose(){name.dispose();email.dispose();password.dispose();confirmation.dispose();super.dispose();}
  String? _validateEmail(String? v){
    if(v==null||!RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(v.trim()))return 'أدخل بريداً إلكترونياً صحيحاً';
    return null;
  }
  Future<void> _submit()async{
    if(!(formKey.currentState?.validate()??false))return;
    if(register&&!accepted){notify(context,'يرجى الموافقة على شروط الاستخدام');return;}
    setState(()=>busy=true);
    try{
      if(register){await widget.api.register(name.text.trim(),email.text.trim(),password.text);
        // The existing PHP registration endpoint creates the user, and login issues its token.
        await widget.api.login(email.text.trim(),password.text);
      }else{await widget.api.login(email.text.trim(),password.text);}
      if(mounted){widget.onLogin();notify(context,'أهلاً بك في سطور');}
    }catch(e){if(mounted)notify(context,'$e');}
    finally{if(mounted)setState(()=>busy=false);}
  }
  @override Widget build(BuildContext context)=>widget.signed?_accountView():_authView();
  Widget _authView()=>ListView(padding:const EdgeInsets.fromLTRB(17,18,17,28),children:[
    Container(decoration:BoxDecoration(borderRadius:BorderRadius.circular(21),
        color:const Color(0xFFF2E8D5)),clipBehavior:Clip.antiAlias,
      child:Column(children:[
        Container(width:double.infinity,padding:const EdgeInsets.symmetric(vertical:23),
          decoration:const BoxDecoration(gradient:LinearGradient(colors:[green,deep])),
          child:Column(children:[
            const BrandMark(size:89),const SizedBox(height:12),
            Text(register?'انضم إلى عائلة سطور':'أهلاً بعودتك إلى سطور',
              style:GoogleFonts.tajawal(color:Colors.white,fontSize:23,fontWeight:FontWeight.w900)),
            const SizedBox(height:5),Text(register?'أنشئ حسابك وابدأ رحلتك مع الكتب':
                'مكتبتك واشتراكاتك بانتظارك',
              style:const TextStyle(color:paleGold,fontSize:13)),
          ])),
        Padding(padding:const EdgeInsets.all(19),child:Form(key:formKey,
          child:Column(crossAxisAlignment:CrossAxisAlignment.stretch,children:[
            Row(children:[Expanded(child:_modeButton('تسجيل الدخول',!register,()=>setState(()=>register=false))),
              const SizedBox(width:8),Expanded(child:_modeButton('إنشاء حساب',register,()=>setState(()=>register=true)))]),
            const SizedBox(height:23),
            if(register)...[
              _fieldLabel('الاسم الكامل'),const SizedBox(height:6),
              TextFormField(controller:name,textInputAction:TextInputAction.next,
                textCapitalization:TextCapitalization.words,
                decoration:const InputDecoration(prefixIcon:Icon(Icons.person_outline),hintText:'اسمك الكامل'),
                validator:(v)=>(v?.trim().runes.length??0)<2?'الاسم يجب أن يتكون من حرفين على الأقل':null),
              const SizedBox(height:15),
            ],
            _fieldLabel('البريد الإلكتروني'),const SizedBox(height:6),
            TextFormField(controller:email,keyboardType:TextInputType.emailAddress,
              textInputAction:TextInputAction.next,autocorrect:false,
              textDirection:TextDirection.ltr,textAlign:TextAlign.right,
              decoration:const InputDecoration(prefixIcon:Icon(Icons.alternate_email),hintText:'name@example.com'),
              validator:_validateEmail),
            const SizedBox(height:15),_fieldLabel('كلمة المرور'),const SizedBox(height:6),
            TextFormField(controller:password,obscureText:!showPassword,
              textInputAction:register?TextInputAction.next:TextInputAction.done,
              decoration:InputDecoration(prefixIcon:const Icon(Icons.lock_outline),
                hintText:register?'10 أحرف على الأقل':'أدخل كلمة المرور',
                suffixIcon:IconButton(onPressed:()=>setState(()=>showPassword=!showPassword),
                  icon:Icon(showPassword?Icons.visibility_off_outlined:Icons.visibility_outlined))),
              validator:(v){if(v==null||v.isEmpty)return 'كلمة المرور مطلوبة';
                if(register&&v.length<10)return 'استخدم 10 أحرف على الأقل';return null;}),
            if(register)...[
              const SizedBox(height:15),_fieldLabel('تأكيد كلمة المرور'),const SizedBox(height:6),
              TextFormField(controller:confirmation,obscureText:!showPassword,
                decoration:const InputDecoration(prefixIcon:Icon(Icons.verified_user_outlined),
                  hintText:'أعد إدخال كلمة المرور'),
                validator:(v)=>v!=password.text?'كلمتا المرور غير متطابقتين':null),
              const SizedBox(height:12),CheckboxListTile(contentPadding:EdgeInsets.zero,
                controlAffinity:ListTileControlAffinity.leading,
                title:const Text('أوافق على شروط الاستخدام وسياسة الخصوصية',
                    style:TextStyle(fontSize:12)),
                value:accepted,activeColor:green,onChanged:(v)=>setState(()=>accepted=v??false)),
            ],
            const SizedBox(height:22),FilledButton.icon(
              onPressed:busy?null:_submit,
              icon:busy?const SizedBox(height:18,width:18,child:CircularProgressIndicator(
                  color:Colors.white,strokeWidth:2)):Icon(register?Icons.person_add_alt_1:Icons.login),
              label:Text(busy?'يرجى الانتظار...':register?'إنشاء الحساب والمتابعة':'دخول إلى حسابي')),
            const SizedBox(height:12),
            Text(register?'سيتم إنشاء حسابك على نفس قاعدة بيانات الموقع':
                'تستخدم هنا نفس حسابك الموجود على موقع سطور',
              textAlign:TextAlign.center,style:const TextStyle(color:muted,fontSize:12)),
          ]))),
      ])),
  ]);
  Widget _modeButton(String title,bool active,VoidCallback action)=>InkWell(onTap:busy?null:action,
    borderRadius:BorderRadius.circular(12),child:Container(
      padding:const EdgeInsets.symmetric(vertical:13),
      decoration:BoxDecoration(color:active?green:Colors.white,
        border:Border.all(color:active?green:edge),borderRadius:BorderRadius.circular(12)),
      child:Text(title,textAlign:TextAlign.center,style:TextStyle(
        color:active?Colors.white:green,fontWeight:FontWeight.w900))));
  Widget _fieldLabel(String value)=>Text(value,
      style:const TextStyle(color:ink,fontSize:14,fontWeight:FontWeight.w800));

  Widget _accountView()=>RefreshIndicator(onRefresh:()async{
    setState(_loadProfile);await profile;
  },child:ListView(children:[
    const SectionTitle('حسابي',subtitle:'بياناتك واشتراكاتك على سطور'),
    FutureBuilder<Map<String,dynamic>>(future:profile,builder:(context,s){
      if(s.hasError)return EmptyState('${s.error}',icon:Icons.cloud_off_outlined);
      if(!s.hasData)return const Center(child:Padding(padding:EdgeInsets.all(22),
          child:CircularProgressIndicator()));
      return Container(margin:const EdgeInsets.symmetric(horizontal:16),
        padding:const EdgeInsets.all(22),decoration:BoxDecoration(
          color:deep,borderRadius:BorderRadius.circular(17)),
        child:Row(children:[const CircleAvatar(radius:28,backgroundColor:paleGold,
            child:Icon(Icons.person,color:green,size:31)),const SizedBox(width:13),
          Expanded(child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
            Text(val(s.data!,'name'),style:const TextStyle(color:Colors.white,fontSize:19,
              fontWeight:FontWeight.w900)),
            Text(val(s.data!,'email'),textDirection:TextDirection.ltr,
              textAlign:TextAlign.right,style:const TextStyle(color:paleGold,fontSize:12)),
          ]))]));
    }),
    const SectionTitle('اشتراكاتي'),
    if(subs!=null)AsyncList(future:subs!,builder:(items)=>items.isEmpty
      ?const EmptyState('لا يوجد اشتراك نشط حالياً',icon:Icons.workspace_premium_outlined)
      :Column(children:items.map((s)=>_record(
        val(s,'plan_title'), 'ينتهي: ${val(s,'ends_at')}',val(s,'status'),
        Icons.workspace_premium)).toList())),
    const SectionTitle('طلباتي'),
    if(orders!=null)AsyncList(future:orders!,builder:(items)=>items.isEmpty
      ?const EmptyState('لم تقم بإرسال طلبات اشتراك بعد',icon:Icons.receipt_long_outlined)
      :Column(children:items.map((o)=>_record(
        '${val(o,'plan_title')} — ${val(o,'amount_bhd')} د.ب',
        'طلب #${val(o,'id')} • ${val(o,'payment_title')}',val(o,'status'),
        Icons.receipt_long_outlined)).toList())),
    Padding(padding:const EdgeInsets.all(20),child:OutlinedButton.icon(
      onPressed:()async{await widget.api.logout();widget.onLogout();},
      icon:const Icon(Icons.logout),label:const Text('تسجيل الخروج'))),
  ]));
  Widget _record(String title,String subtitle,String status,IconData icon)=>
    Container(margin:const EdgeInsets.fromLTRB(16,0,16,10),child:Card(child:ListTile(
      leading:Icon(icon,color:gold),title:Text(title,style:const TextStyle(fontWeight:FontWeight.w800)),
      subtitle:Text(subtitle),trailing:Text(status,style:const TextStyle(color:green,fontSize:12)))));
}
