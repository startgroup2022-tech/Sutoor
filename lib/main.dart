import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'api.dart';

const green = Color(0xFF064833);
const gold = Color(0xFFAD7C22);
const cream = Color(0xFFFAF7EF);
const ink = Color(0xFF182A25);
void main() { WidgetsFlutterBinding.ensureInitialized(); runApp(const SutoorApp()); }

String val(Map<String,dynamic> m,String key,[String fallback='']) => m[key]?.toString() ?? fallback;
int numId(Map<String,dynamic> m) => int.tryParse(val(m,'id')) ?? 0;
Color coverColor(Map<String,dynamic> book) {
  final c = val(book,'color','#176653');
  if (RegExp(r'^#[0-9a-fA-F]{6}$').hasMatch(c)) return Color(int.parse('FF${c.substring(1)}',radix:16));
  return green;
}

class SutoorApp extends StatefulWidget { const SutoorApp({super.key}); @override State<SutoorApp> createState()=>_SutoorAppState(); }
class _SutoorAppState extends State<SutoorApp> {
  final api = SutoorApi();
  bool ready = false; bool signed = false; int tab=0;
  @override void initState(){super.initState(); _restore();}
  Future<void> _restore() async {await api.restore(); if(mounted)setState((){signed=api.loggedIn;ready=true;});}
  void signedIn(){setState((){signed=true;tab=4;});}
  void signedOut(){setState((){signed=false;tab=0;});}
  @override void dispose(){api.dispose();super.dispose();}
  @override Widget build(BuildContext context) => MaterialApp(
    debugShowCheckedModeBanner:false, title:'سطور | مكتبة رقمية',
    locale:const Locale('ar'),
    theme:ThemeData(useMaterial3:true, scaffoldBackgroundColor:cream,
      colorScheme:ColorScheme.fromSeed(seedColor:green, primary:green,secondary:gold, surface:cream),
      appBarTheme:const AppBarTheme(backgroundColor:cream,foregroundColor:green,centerTitle:true),
      filledButtonTheme:FilledButtonThemeData(style:FilledButton.styleFrom(backgroundColor:green,
        foregroundColor:Colors.white,padding:const EdgeInsets.symmetric(vertical:14,horizontal:18))),
      cardTheme:CardThemeData(color:Colors.white,shape:RoundedRectangleBorder(borderRadius:BorderRadius.circular(16)))),
    builder:(context,child)=>Directionality(textDirection:TextDirection.rtl,child:child!),
    home:!ready?const Scaffold(body:Center(child:CircularProgressIndicator())):
      Scaffold(appBar:AppBar(title: Row(mainAxisSize:MainAxisSize.min,children:[
        ClipOval(child:Image.asset('assets/images/brand.jpg',height:39,width:39,fit:BoxFit.cover)),
        const SizedBox(width:9),const Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
          Text('سطور',style:TextStyle(fontWeight:FontWeight.w900,fontSize:25)),
          Text('مكتبة رقمية',style:TextStyle(fontSize:10,color:gold))])])),
        body:IndexedStack(index:tab,children:[
          HomePage(api:api,onExplore:()=>setState(()=>tab=1)),
          BooksPage(api:api),
          MyLibraryPage(api:api,signed:signed,onLogin:()=>setState(()=>tab=4)),
          PlansPage(api:api,onLogin:()=>setState(()=>tab=4)),
          AccountPage(api:api,signed:signed,onLogin:signedIn,onLogout:signedOut),
        ]),
        bottomNavigationBar:NavigationBar(selectedIndex:tab,onDestinationSelected:(v)=>setState(()=>tab=v),
          destinations:const [NavigationDestination(icon:Icon(Icons.home_outlined),selectedIcon:Icon(Icons.home),label:'الرئيسية'),
            NavigationDestination(icon:Icon(Icons.search_outlined),selectedIcon:Icon(Icons.search),label:'استكشاف'),
            NavigationDestination(icon:Icon(Icons.bookmark_border),selectedIcon:Icon(Icons.bookmark),label:'مكتبتي'),
            NavigationDestination(icon:Icon(Icons.workspace_premium_outlined),label:'الباقات'),
            NavigationDestination(icon:Icon(Icons.person_outline),label:'حسابي')]),
      ));
}

Widget panelTitle(String title,{String? subtitle})=>Padding(padding:const EdgeInsets.fromLTRB(16,20,16,10),child:Column(
  crossAxisAlignment:CrossAxisAlignment.start,children:[Text(title,style:const TextStyle(fontSize:21,color:green,fontWeight:FontWeight.w900)),
    if(subtitle!=null)Text(subtitle,style:const TextStyle(color:Colors.black54))]));

class LoadList extends StatelessWidget {
  const LoadList({super.key,required this.future,required this.builder});
  final Future<List<Map<String,dynamic>>> future;
  final Widget Function(List<Map<String,dynamic>>) builder;
  @override Widget build(BuildContext context)=>FutureBuilder<List<Map<String,dynamic>>>(future:future,builder:(context,snapshot){
    if(snapshot.connectionState!=ConnectionState.done)return const Center(child:Padding(padding:EdgeInsets.all(32),child:CircularProgressIndicator()));
    if(snapshot.hasError)return Center(child:Padding(padding:const EdgeInsets.all(25),child:Text('${snapshot.error}',textAlign:TextAlign.center)));
    return builder(snapshot.data??[]);
  });
}

class BookCover extends StatelessWidget {const BookCover({super.key,required this.book,this.width=120});final Map<String,dynamic> book;final double width;
 @override Widget build(BuildContext context){ final cover=val(book,'cover');
   final bookTitle=val(book,'title');
   return Container(width:width,height:width*1.42,clipBehavior:Clip.antiAlias,
     decoration:BoxDecoration(borderRadius:BorderRadius.circular(9),gradient:LinearGradient(
       colors:[coverColor(book),coverColor(book).withValues(alpha:.77)],begin:Alignment.topRight,end:Alignment.bottomLeft),
       boxShadow:const [BoxShadow(color:Color(0x22000000),blurRadius:8,offset:Offset(0,4))]),
     child:cover.startsWith('assets/img/covers/')
       ?Image.network('https://sutoor.it.com/$cover',fit:BoxFit.cover,errorBuilder:(_,__,___)=>_fallback(bookTitle))
       :_fallback(bookTitle)); }
 Widget _fallback(String title)=>Padding(padding:const EdgeInsets.all(9),child:Column(mainAxisAlignment:MainAxisAlignment.center,children:[
   const Icon(Icons.auto_stories,color:Color(0xFFEAD49E),size:26),const SizedBox(height:10),
   Text(title,textAlign:TextAlign.center,maxLines:4,style:const TextStyle(fontWeight:FontWeight.w900,color:Colors.white,fontSize:15)),
   const Divider(color:Color(0xFFEAD49E)),Text(val(book,'author'),textAlign:TextAlign.center,maxLines:2,
      style:const TextStyle(color:Color(0xFFF4E4BC),fontSize:10))]));
}
class BookTile extends StatelessWidget {const BookTile({super.key,required this.book,required this.api});final Map<String,dynamic> book;final SutoorApi api;
 @override Widget build(BuildContext context)=>InkWell(onTap:()=>Navigator.push(context,MaterialPageRoute(builder:(_)=>BookDetails(api:api,book:book))),
 child:Column(children:[BookCover(book:book,width:125),const SizedBox(height:7),Text(val(book,'title'),textAlign:TextAlign.center,maxLines:2,overflow:TextOverflow.ellipsis,
    style:const TextStyle(fontWeight:FontWeight.bold)),Text(val(book,'author'),maxLines:1,overflow:TextOverflow.ellipsis,
    style:const TextStyle(color:Colors.black54,fontSize:12))])); }
class BooksGrid extends StatelessWidget {const BooksGrid({super.key,required this.books,required this.api});final List<Map<String,dynamic>> books;final SutoorApi api;
 @override Widget build(BuildContext context)=>GridView.builder(shrinkWrap:true,physics:const NeverScrollableScrollPhysics(),
  padding:const EdgeInsets.all(14),itemCount:books.length,gridDelegate:const SliverGridDelegateWithMaxCrossAxisExtent(
  maxCrossAxisExtent:195,childAspectRatio:.56,mainAxisSpacing:16,crossAxisSpacing:14),
  itemBuilder:(context,i)=>BookTile(book:books[i],api:api)); }

class HomePage extends StatefulWidget {const HomePage({super.key,required this.api,required this.onExplore});final SutoorApi api;final VoidCallback onExplore;
 @override State<HomePage> createState()=>_HomePageState();}
class _HomePageState extends State<HomePage>{late Future<List<Map<String,dynamic>>> books;late Future<List<Map<String,dynamic>>> categories;
 @override void initState(){super.initState();books=widget.api.list('/books');categories=widget.api.list('/categories');}
 @override Widget build(BuildContext context)=>RefreshIndicator(onRefresh:()async{setState((){books=widget.api.list('/books');categories=widget.api.list('/categories');});await books;},
 child:ListView(children:[
  Container(height:216,decoration:const BoxDecoration(image:DecorationImage(image:AssetImage('assets/images/hero-library.jpg'),fit:BoxFit.cover)),
   child:Container(color:const Color(0xB900382A),padding:const EdgeInsets.all(24),child:Column(mainAxisAlignment:MainAxisAlignment.center,children:[
      const Text('رحلة في عالم الكتب',textAlign:TextAlign.center,style:TextStyle(color:Colors.white,fontSize:27,fontWeight:FontWeight.w900)),
      const SizedBox(height:7),const Text('آلاف الصفحات بانتظارك، باشتراك واحد',style:TextStyle(color:Color(0xFFF1D79B),fontSize:16)),
      const SizedBox(height:15),FilledButton.icon(onPressed:widget.onExplore,icon:const Icon(Icons.auto_stories),label:const Text('استكشف الكتب'))]))),
  panelTitle('تصفّح حسب التصنيف'),SizedBox(height:100,child:LoadList(future:categories,builder:(items)=>ListView.separated(
    scrollDirection:Axis.horizontal,padding:const EdgeInsets.symmetric(horizontal:16),itemCount:items.length,separatorBuilder:(_,__)=>const SizedBox(width:9),
    itemBuilder:(context,i)=>Container(width:115,padding:const EdgeInsets.all(11),decoration:BoxDecoration(color:Colors.white,borderRadius:BorderRadius.circular(13)),
    child:Column(mainAxisAlignment:MainAxisAlignment.center,children:[const Icon(Icons.category_outlined,color:gold),const SizedBox(height:5),
      Text(val(items[i],'name'),maxLines:2,textAlign:TextAlign.center,style:const TextStyle(fontSize:12,fontWeight:FontWeight.bold))]))))),
  Container(margin:const EdgeInsets.all(14),padding:const EdgeInsets.all(19),decoration:BoxDecoration(color:green,borderRadius:BorderRadius.circular(17)),
    child:const Column(children:[Text('مكتبة واحدة، عوالم بلا حدود',style:TextStyle(color:Color(0xFFF4D48B),fontWeight:FontWeight.bold,fontSize:20)),
      SizedBox(height:7),Text('استمتع بالقراءة من أي مكان، وتابع اشتراكك من حسابك.',textAlign:TextAlign.center,style:TextStyle(color:Colors.white))])),
  panelTitle('مختارات سطور',subtitle:'يتم تحديث الكتب مباشرة من لوحة الإدارة'),
  LoadList(future:books,builder:(items)=>items.isEmpty?const Center(child:Text('لا توجد كتب منشورة حالياً')):
   BooksGrid(books:items.take(6).toList(),api:widget.api)),
 ]));}

class BooksPage extends StatefulWidget {const BooksPage({super.key,required this.api});final SutoorApi api;@override State<BooksPage> createState()=>_BooksPageState();}
class _BooksPageState extends State<BooksPage>{String query='';late Future<List<Map<String,dynamic>>> books;
 @override void initState(){super.initState();books=widget.api.list('/books');}
 @override Widget build(BuildContext context)=>Column(children:[panelTitle('جميع الكتب'),Padding(padding:const EdgeInsets.symmetric(horizontal:16),child:TextField(
   onChanged:(s)=>setState(()=>query=s.trim().toLowerCase()),decoration:const InputDecoration(prefixIcon:Icon(Icons.search),
   hintText:'ابحث عن كتاب أو مؤلف أو تصنيف',filled:true,fillColor:Colors.white,border:OutlineInputBorder()))),
   Expanded(child:RefreshIndicator(onRefresh:()async{setState(()=>books=widget.api.list('/books'));await books;},
    child:LoadList(future:books,builder:(items){final filtered=items.where((e)=>[val(e,'title'),val(e,'author'),val(e,'category')]
      .any((v)=>v.toLowerCase().contains(query))).toList();return filtered.isEmpty?const Center(child:Text('لا توجد نتائج')):
      ListView(children:[BooksGrid(books:filtered,api:widget.api)]);}))) ]);}

/// Customer library: only books for which the server confirms reading access.
/// This is intentionally not a PDF reader; no protected-content endpoint exists yet.
class MyLibraryPage extends StatefulWidget {
 const MyLibraryPage({super.key,required this.api,required this.signed,required this.onLogin});
 final SutoorApi api; final bool signed; final VoidCallback onLogin;
 @override State<MyLibraryPage> createState()=>_MyLibraryPageState();
}
class _MyLibraryPageState extends State<MyLibraryPage> {
 late Future<List<Map<String,dynamic>>> accessible;
 @override void initState(){super.initState();accessible=_load();}
 @override void didUpdateWidget(covariant MyLibraryPage oldWidget){super.didUpdateWidget(oldWidget);if(oldWidget.signed!=widget.signed)accessible=_load();}
 Future<List<Map<String,dynamic>>> _load() async {
   if(!widget.signed)return [];
   final books=await widget.api.list('/books');
   final allowed=<Map<String,dynamic>>[];
   for(final book in books){
     try {final access=await widget.api.access(numId(book));if(access['can_read']==true)allowed.add(book);}
     on ApiException catch(e) {if(e.statusCode==401)rethrow;}
   }
   return allowed;
 }
 @override Widget build(BuildContext context){
   if(!widget.signed)return Center(child:Padding(padding:const EdgeInsets.all(25),child:Column(
      mainAxisSize:MainAxisSize.min,children:[const Icon(Icons.bookmarks_outlined,size:56,color:gold),
      const SizedBox(height:15),const Text('مكتبتك الشخصية',style:TextStyle(fontSize:24,color:green,fontWeight:FontWeight.bold)),
      const SizedBox(height:10),const Text('سجّل دخولك لعرض الكتب المتاحة حسب اشتراكك',textAlign:TextAlign.center),
      const SizedBox(height:20),FilledButton(onPressed:widget.onLogin,child:const Text('تسجيل الدخول'))])));
   return RefreshIndicator(onRefresh:() async {setState(()=>accessible=_load());await accessible;},
    child:ListView(children:[panelTitle('مكتبتي',subtitle:'الكتب المتاحة لك حسب صلاحيات الموقع'),
      LoadList(future:accessible,builder:(books)=>books.isEmpty
       ?const Padding(padding:EdgeInsets.all(30),child:Text('لا توجد كتب مفعّلة للقراءة حالياً. تحقق من اشتراكك أو تصفح الكتب المجانية.',textAlign:TextAlign.center))
       :BooksGrid(books:books,api:widget.api))]));
 }
}

class BookDetails extends StatefulWidget {const BookDetails({super.key,required this.api,required this.book});final SutoorApi api;final Map<String,dynamic> book;
 @override State<BookDetails> createState()=>_BookDetailsState();}
class _BookDetailsState extends State<BookDetails>{bool checking=false;
 Future<void> checkAccess()async {setState(()=>checking=true);try{final a=await widget.api.access(numId(widget.book));if(!mounted)return;
   final canRead=a['can_read']==true;final canDownload=a['can_download']==true;
   await showDialog(context:context,builder:(ctx)=>AlertDialog(title:const Text('صلاحيات الكتاب'),
    content:Text('القراءة: ${canRead?'مسموحة':'غير مسموحة'}\nالتنزيل: ${canDownload?'مسموح':'غير مسموح'}\n\nقارئ الكتب المحمي ومسار التنزيل لم يُفعّلا بعد في API الحالية.'),
    actions:[TextButton(onPressed:()=>Navigator.pop(ctx),child:const Text('موافق'))]));
 }catch(e){if(mounted)ScaffoldMessenger.of(context).showSnackBar(SnackBar(content:Text('$e')));}finally{if(mounted)setState(()=>checking=false);}}
 @override Widget build(BuildContext context)=>Scaffold(appBar:AppBar(title:const Text('تفاصيل الكتاب')),body:ListView(padding:const EdgeInsets.all(20),children:[
  Center(child:BookCover(book:widget.book,width:180)),const SizedBox(height:15),Text(val(widget.book,'title'),textAlign:TextAlign.center,
   style:const TextStyle(fontWeight:FontWeight.w900,fontSize:27,color:green)),Text(val(widget.book,'author'),textAlign:TextAlign.center,
   style:const TextStyle(color:gold,fontSize:16)),const SizedBox(height:20),
  Wrap(alignment:WrapAlignment.center,spacing:12,children:[Chip(label:Text(val(widget.book,'category','كتاب رقمي'))),
    Chip(label:Text('${val(widget.book,'rating','–')} ★')),
    Chip(label:Text(val(widget.book,'is_free')=='1'?'مجاني':'حسب الاشتراك'))]),
  const SizedBox(height:20),Text(val(widget.book,'description','لا يوجد وصف لهذا الكتاب حالياً.'),style:const TextStyle(height:1.9)),
  const SizedBox(height:25),FilledButton.icon(onPressed:checking?null:checkAccess,icon:const Icon(Icons.verified_user_outlined),
    label:Text(checking?'جاري التحقق...':'التحقق من القراءة والتنزيل'))])); }

class PlansPage extends StatefulWidget {const PlansPage({super.key,required this.api,required this.onLogin});final SutoorApi api;final VoidCallback onLogin;
 @override State<PlansPage> createState()=>_PlansPageState();}
class _PlansPageState extends State<PlansPage>{late Future<List<Map<String,dynamic>>> plans;
 @override void initState(){super.initState();plans=widget.api.list('/plans');}
 Future<void> order(Map<String,dynamic> plan)async {if(!widget.api.loggedIn){widget.onLogin();return;}
  try {final methods=await widget.api.list('/payment-methods');if(!mounted)return;
   if(methods.isEmpty){ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content:Text('لا تتوفر طرق دفع حالياً')));return;}
   await showModalBottomSheet(context:context,isScrollControlled:true,showDragHandle:true,builder:(ctx)=>SafeArea(child:Padding(
     padding:const EdgeInsets.all(20),child:Column(mainAxisSize:MainAxisSize.min,crossAxisAlignment:CrossAxisAlignment.stretch,children:[
     Text('اختر طريقة الدفع — ${val(plan,'title')}',style:const TextStyle(fontWeight:FontWeight.bold,fontSize:20)),
     const SizedBox(height:12),...methods.map((m)=>ListTile(leading:const Icon(Icons.payments_outlined,color:green),
      title:Text(val(m,'title')),subtitle:Text(val(m,'instructions'),maxLines:2),onTap:()async{
        Navigator.pop(ctx);try{final result=await widget.api.order(numId(plan),numId(m));if(!mounted)return;
        final url=result['whatsapp_url']?.toString();ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content:Text('تم تسجيل الطلب #${result['id']} وهو بانتظار موافقة الإدارة')));
        if(url!=null&&url.startsWith('https://wa.me/')){
          final uri=Uri.tryParse(url);if(uri!=null)await launchUrl(uri,mode:LaunchMode.externalApplication);
        }
        }catch(e){if(mounted)ScaffoldMessenger.of(context).showSnackBar(SnackBar(content:Text('$e')));}
      })),const SizedBox(height:15)]))));
  }catch(e){if(mounted)ScaffoldMessenger.of(context).showSnackBar(SnackBar(content:Text('$e')));}}
 @override Widget build(BuildContext context)=>ListView(children:[panelTitle('باقات الاشتراك',subtitle:'الأسعار والباقات وطرق الدفع تُدار من الموقع'),
  LoadList(future:plans,builder:(items)=>items.isEmpty?const Padding(padding:EdgeInsets.all(30),child:Text('لا توجد باقات منشورة حالياً')):
   Column(children:items.map((p)=>Card(margin:const EdgeInsets.fromLTRB(15,4,15,15),child:Padding(padding:const EdgeInsets.all(22),child:Column(
    crossAxisAlignment:CrossAxisAlignment.stretch,children:[Text(val(p,'title'),style:const TextStyle(fontWeight:FontWeight.w900,fontSize:23,color:green)),
    const SizedBox(height:6),Text('${val(p,'price_bhd','0')} د.ب',style:const TextStyle(fontSize:30,color:gold,fontWeight:FontWeight.bold)),
    Text('المدة: ${val(p,'duration_days')} يوم'),const SizedBox(height:12),Text(val(p,'description')),
    const SizedBox(height:15),FilledButton(onPressed:()=>order(p),child:const Text('طلب الاشتراك'))])))).toList()))]);}

class AccountPage extends StatefulWidget {const AccountPage({super.key,required this.api,required this.signed,required this.onLogin,required this.onLogout});
 final SutoorApi api;final bool signed;final VoidCallback onLogin,onLogout;
 @override State<AccountPage> createState()=>_AccountPageState();}
class _AccountPageState extends State<AccountPage>{final email=TextEditingController(),password=TextEditingController(),name=TextEditingController();
 bool register=false,busy=false;
 @override void dispose(){email.dispose();password.dispose();name.dispose();super.dispose();}
 Future<void> submit() async {setState(()=>busy=true);try{
   if(register){await widget.api.register(name.text.trim(),email.text.trim(),password.text);
    if(mounted){setState(()=>register=false);ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content:Text('تم إنشاء الحساب. سجّل الدخول الآن')));}}
   else{await widget.api.login(email.text.trim(),password.text);widget.onLogin();}
 }catch(e){if(mounted)ScaffoldMessenger.of(context).showSnackBar(SnackBar(content:Text('$e')));}finally{if(mounted)setState(()=>busy=false);}}
 @override Widget build(BuildContext context){if(!widget.signed)return ListView(padding:const EdgeInsets.all(22),children:[panelTitle(register?'حساب جديد':'تسجيل الدخول'),
   if(register)TextField(controller:name,decoration:const InputDecoration(labelText:'الاسم',border:OutlineInputBorder())),
   const SizedBox(height:11),TextField(controller:email,keyboardType:TextInputType.emailAddress,
    decoration:const InputDecoration(labelText:'البريد الإلكتروني',border:OutlineInputBorder())),const SizedBox(height:11),
   TextField(controller:password,obscureText:true,decoration:const InputDecoration(labelText:'كلمة المرور',border:OutlineInputBorder())),
   const SizedBox(height:18),FilledButton(onPressed:busy?null:submit,child:Text(busy?'انتظر...':register?'إنشاء حساب':'دخول')),
   TextButton(onPressed:()=>setState(()=>register=!register),child:Text(register?'لديك حساب؟ تسجيل الدخول':'ليس لديك حساب؟ أنشئ حساباً'))]);
 return ListView(children:[panelTitle('حسابي'),FutureBuilder<Map<String,dynamic>>(future:widget.api.me(),builder:(context,s){
 if(!s.hasData)return Padding(padding:const EdgeInsets.all(14),child:Text(s.hasError?'${s.error}':'جارٍ تحميل البيانات...'));
 return ListTile(leading:const CircleAvatar(child:Icon(Icons.person)),title:Text(val(s.data!,'name')),
 subtitle:Text(val(s.data!,'email')));}),
 panelTitle('طلباتي'),LoadList(future:widget.api.orders(),builder:(items)=>items.isEmpty?const ListTile(title:Text('لا توجد طلبات اشتراك بعد')):
  Column(children:items.map((o)=>ListTile(leading:const Icon(Icons.receipt_long_outlined,color:green),
   title:Text('${val(o,'plan_title')} — ${val(o,'amount_bhd')} د.ب'),
   subtitle:Text('رقم #${val(o,'id')} • ${val(o,'payment_title')}'),trailing:Text(val(o,'status')))).toList())),
 panelTitle('اشتراكاتي'),LoadList(future:widget.api.subscriptions(),builder:(items)=>items.isEmpty?const ListTile(title:Text('لا يوجد اشتراك نشط')):
  Column(children:items.map((s)=>ListTile(title:Text(val(s,'plan_title')),subtitle:Text('ينتهي: ${val(s,'ends_at')}'),trailing:Text(val(s,'status')))).toList())),
 Padding(padding:const EdgeInsets.all(20),child:OutlinedButton.icon(onPressed:()async{await widget.api.logout();widget.onLogout();},
 icon:const Icon(Icons.logout),label:const Text('تسجيل الخروج')))]);}
}
