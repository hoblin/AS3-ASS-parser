package classes{ 

  import flash.net.*;
  import flash.events.Event;

  import events.*;

  public class Subtitle extends Object
  {
    private var _owner:DSPlayer;
    private var _captions:Array = new Array();

    // ASS parser vars
    private var _mode:String;
    private var _file:String;
    private var _format:Array;
    private var _styles:Object = new Object();
    private var _styles_arr:Array = new Array();
    private var x_resolution:Number;
    private var y_resolution:Number;

    public function Subtitle(p_owner:DSPlayer, p_file:String){
      _owner = p_owner;
      _file = p_file;
    }

    private function parseSubFile(evt:Event):void{
      //debug('\t\t\t Subtitle \t -> parseSubFile');
      parseASS(evt.target.data);
      //debug('\t\t\t Subtitle \t <- parseSubFile');
    }

    private function parseASS(dat:String):void{
      var stringsArr:Array = dat.split(/\r?\n/);
      for each (var str:String in stringsArr){
        parseASSString(str)
      }
      _owner.dispatchEvent(new PlayerEvent(PlayerEvent.SUB_PARSED));
    };

    private function parseASSString(dat:String):void{
      /*debug('\nASS string:'+dat);*/
      var blockReg = /^\[([^\]]+)\]$/;
      var blockRes = blockReg.exec(dat);

      var infoReg = /^(?P<ident>\w+)\:\s?(?P<val>.+)(?:\s+)?$/g;
      var infoRes = infoReg.exec(dat);

      var formatReg = /^Format\:\s?((?:(?:\w+)\,?\s?)+)/g;
      var formatRes = formatReg.exec(dat);

      var styleReg = /^Style\:\s?((?:(?:[^,]*)\,?\s?)+)/g;
      var styleRes = styleReg.exec(dat);

      var dialogReg = /^Dialogue\:\s?((?:(?:[^,]*)\,?)+)/g;
      var dialogRes = dialogReg.exec(dat);

      if(blockRes){
        // change current mode
        switch (blockRes[1])
        {
          case 'Script Info' :
            _mode = 'info';
          break;
          case 'V4+ Styles' :
            _mode = 'styles';
          break;
          case 'Events' :
            _mode = 'dialogs';
          break;
        }
      }else if(formatRes){
        _format = formatRes[1].split(", ");
      }else if(styleRes){
        var styleArray = styleRes[1].split(",");
        var styleObj:Object = new Object();
        for (var p:String in _format){
          styleObj[_format[p]] = styleArray[p];
        }
        /*debug(styleObj.Name+'.Fontname:'+styleObj.Fontname)*/
        _styles[styleObj.Name] = styleObj;
        _styles_arr.push(styleObj);
      }else if(dialogRes){
        var dialogObject = new Object();
        var dialogParseRegString = '';
        for (var f:String in _format){
          if(_format[f] != 'Text'){
            dialogParseRegString += '(?P<'+_format[f]+'>[^,]*),';
          }else{
            dialogParseRegString += '(?P<'+_format[f]+'>.+)?\r?$';
          }
        }
        var dialogParseReg = new RegExp(dialogParseRegString);
        var dialogParseRes = dialogParseReg.exec(dialogRes[1]);
        for (var s:String in _format)
        {
          var fieldName = _format[s];
          if(fieldName == 'Style'){
            var dialog_style = _styles[dialogParseRes[fieldName]];
            if(dialog_style == undefined){
              dialog_style = _styles_arr[0];
            }
            dialogObject[fieldName] = dialog_style;
          }else{
            dialogObject[fieldName] = dialogParseRes[fieldName];
          }
        }
        parseASSDialog(dialogObject);
      }else if((_mode == 'info')&&infoRes){
        switch (infoRes.ident){
          case 'PlayResX' :
            x_resolution = Number(infoRes.val);
          break;
          case 'PlayResY' :
            y_resolution = Number(infoRes.val);
          break;
        }
      }
      /*debug('\nASS string parsed');*/
    };

    private function parseASSDialog(dialog:Object):void{
      /*debug('\tASS Dialog:'+dialog);*/
      var captionAnmationObject = new Object();
      var captionObject = new Object();

      captionObject['begin'] = Number(Strings.seconds( dialog.Start ));
      captionObject['end'] = Number(Strings.seconds( dialog.End ));

      captionObject['active'] = false;
      captionObject['outline'] = dialog.Style.Outline;
      captionObject['outlineColor'] = parseColor(dialog.Style.OutlineColour);

      captionObject['shadow'] = dialog.Style.Shadow;
      captionObject['shadowColor'] = parseColor(dialog.Style.BackColour);

      captionObject['marginL'] = dialog.Style.MarginL / x_resolution;
      captionObject['marginR'] = dialog.Style.MarginR / x_resolution;
      captionObject['marginV'] = dialog.Style.MarginV / y_resolution;

      captionObject['font'] = dialog.Style.Fontname;
      captionObject['size'] = dialog.Style.Fontsize / y_resolution;
      captionObject['color'] = parseColor(dialog.Style.PrimaryColour);
      
      captionObject['bold'] = (dialog.Style.Bold != 0);
      captionObject['italic'] = (dialog.Style.Italic != 0);
      captionObject['underline'] = (dialog.Style.Underline != 0);

      var numberAlign = Number(dialog.Style.Alignment);
      if(numberAlign > 6){
        captionObject['valign'] = 'top';
        numberAlign -= 6;
      }else if(numberAlign > 3){
        captionObject['valign'] = 'mid';
        numberAlign -= 3;
      }
      if(numberAlign == 1){
        captionObject['align'] = 'left';
      }else if(numberAlign == 3){
        captionObject['align'] = 'right';
      }

      // removing karaoke effects
      var karaokeReplaceReg = /\{\\k\w?\d+\}/g;
      var cleanedText:String = dialog.Text.replace(karaokeReplaceReg, '');

      var paramsStringReg = /(?:\{(?P<params>[^\}]+)\})(?P<text>.+)/;
      var paramsStringRes = paramsStringReg.exec(cleanedText);
      if(paramsStringRes){
        cleanedText = paramsStringRes.text;
      }

      // INLINE TAG PARSING
      // adding spaces
      var hReplaceReg = /\\h/g;
      cleanedText = cleanedText.replace(hReplaceReg, ' ');

      // adding line breaks
      var NReplaceReg = /\\(N|n)/g;
      cleanedText = cleanedText.replace(NReplaceReg, '<br>');
      // font string

      var fontReg = /(?P<before>.*)\{(?P<c>\\c\&H?(?P<blue>\w{2})(?P<green>\w{2})(?P<red>\w{2})[\&H]?)?(?P<3c>\\3c\&H(?P<3blue>\w{2})(?P<3green>\w{2})(?P<3red>\w{2})[\&H]?)?(\\fs\d+)?(?P<bord>\\bord(?P<border>\d))?\}(?P<after>.*)/;
      var fontRes = fontReg.exec(cleanedText);
      var fontColor = '';
      var fontSize = '';
      while (fontRes){
        if(fontRes.c){
          fontColor = ' color="#' + fontRes.red + fontRes.green + fontRes.blue + '"';
        }else{
          fontColor = '';
        }
        cleanedText = fontRes.before + '<font >' + fontRes.after + '</font>';
        fontRes = fontReg.exec(cleanedText);
      }

      // removing inline tags
      var inlineTagReg = /\{\\p1\}.+\{\\p0\}/g;
      cleanedText = cleanedText.replace(inlineTagReg, '');

      // removing inline params
      var inlineModReg = /\{\\[^\}]+\}/g;
      cleanedText = cleanedText.replace(inlineModReg, '');

      // removing comments
      var commentsReg = /\{[^\}]+\}/g;
      cleanedText = cleanedText.replace(commentsReg, '');

      // removing draw strings
      var drawReg = /m [\d\sl]+/g;
      cleanedText = cleanedText.replace(drawReg, '');

      if(cleanedText != ''){
        captionObject['text'] = cleanedText;

        /*debug('\t\tparse mods');*/
        if(paramsStringRes){
          /*debug('params:'+paramsStringRes.params);*/
          var paramsReg = /\\(?P<ident>\d?[a-z]+)(?P<params>(?:[\&HA-F\d]+)*(?:\([^\)]+\))?)/ig;
          var paramsRes = paramsReg.exec(paramsStringRes.params);
          while (paramsRes){
            /*debug('ident:'+paramsRes.ident+'\tparams:'+paramsRes.params+'\t text:'+cleanedText);*/
            switch (paramsRes.ident){
              case 'pos' :
              /*debug('\t\tpos');*/
                var mod_x = paramsRes.params.match(/\((?P<val>-?[\d.]+),\s?-?[\d.]+\)/).val;
                var mod_y = paramsRes.params.match(/\(-?[\d.]+,\s?(?P<val>-?[\d.]+)\)/).val;
                captionObject['x'] = mod_x / x_resolution;
                captionObject['y'] = mod_y / y_resolution;
                captionObject['valign'] = 'pos';
                /*debug('\t\tparsed');*/
              break;
              case 'move' :
              /*debug('\t\tmove');*/
                var mod_x_start = paramsRes.params.match(/\((?P<val>-?[\d.]+),\s?(?:-?[\d.]+,?\s?){3,5}\)/).val;
                var mod_y_start = paramsRes.params.match(/\((?:-?[\d.]+,\s?)(?P<val>-?[\d.]+),\s?(?:-?[\d.]+,?\s?){2,4}\)/).val;
                var mod_x_end = paramsRes.params.match(/\((?:-?[\d.]+,\s?){2}(?P<val>-?[\d.]+),\s?(?:-?[\d.]+,?\s?){1,3}\)/).val;
                var mod_y_end = paramsRes.params.match(/\((?:-?[\d.]+,\s?){3}(?P<val>-?[\d.]+),?\s?(?:-?[\d.]+,?\s?)*\)/).val;
                var mod_time_start_res = paramsRes.params.match(/\((?:-?[\d.]+,\s?){4}(?P<val>-?[\d.]+),\s?(?:-?[\d.]+,?\s?)\)/);
                var mod_time_end_res = paramsRes.params.match(/\((?:-?[\d.]+,\s?){5}(?P<val>-?[\d.]+)\s?\)/);
                var mod_time_start = 0;
                var mod_time_end = captionObject['end'] - captionObject['begin'];
                /*debug('\t\t\tprepared')*/
                if(mod_time_start_res){
                  mod_time_start = Number(mod_time_start_res.val) / 100;
                }
                if(mod_time_end_res){
                  mod_time_end = Number(mod_time_end_res.val) / 100;
                }
                captionObject['x'] = mod_x_start / x_resolution;
                captionObject['y'] = mod_y_start / y_resolution;
                captionAnmationObject['x'] = mod_x_end / x_resolution;
                captionAnmationObject['y'] = mod_y_end / y_resolution;
                captionAnmationObject['delay'] = mod_time_start;
                captionAnmationObject['time'] = mod_time_end;
                captionObject['valign'] = 'move';
                /*debug('\t\tparsed');*/
              break;
              case 'c' :
              /*debug('\t\tc');*/
                var mod_color = parseColor(paramsRes.params);
                captionObject['color'] = mod_color;
                /*debug('\t\tparsed');*/
              break;
              case '3c' :
              /*debug('\t\t3c');*/
                var mod_outline_color = parseColor(paramsRes.params);
                captionObject['outlineColor'] = mod_outline_color;
                /*debug('\t\tparsed');*/
              break;
              case 'fad' :
              /*debug('\t\tfad');*/
                captionObject['fadeIn'] = Number(paramsRes.params.match(/\((?P<val>[\d.]+),\s?[\d.]+\)/).val) / 1000;
                captionObject['fadeOut'] = Number(paramsRes.params.match(/\([\d.]+,\s?(?P<val>[\d.]+)\)/).val) / 1000;
                /*debug('\t\tparsed');*/
              break;
              case 'fs' :
                captionObject['size'] = Number(paramsRes.params) / y_resolution;
              break;
              case 'frx' :
                captionObject['frx'] = Number(paramsRes.params);
              break;
              case 'fry' :
                captionObject['fry'] = Number(paramsRes.params);
              break;
              case 'frz' :
                captionObject['frz'] = Number(paramsRes.params);
              break;
              case 'a' :
                var numberAlignMod = Number(paramsRes.params);
                if(numberAlignMod > 6){
                  captionObject['valign'] = 'top';
                  numberAlignMod -= 6;
                }else if(numberAlignMod > 3){
                  captionObject['valign'] = 'mid';
                  numberAlignMod -= 3;
                }
                if(numberAlignMod == 1){
                  captionObject['align'] = 'left';
                }else if(numberAlignMod == 3){
                  captionObject['align'] = 'right';
                }
              break;
            }
            paramsRes = paramsReg.exec(paramsStringRes.params);
          }
        }
        /*debug('\t\tmods redy');*/

        captionObject['animation'] = captionAnmationObject;
        _captions.push(new Caption(_owner, captionObject));
        /*debug('\tASS Dialog parsed');*/
      }
    }

    private function parseColor(str:String):Number{
      var colorReg = /^\&H?(?P<alpha>\w{2})?(?P<blue>\w{2})(?P<green>\w{2})(?P<red>\w{2})[\&H]?$/;
      var colorRes = colorReg.exec(str);
      /*debug('COLOR:'+str+'\t'+'0x'+colorRes.red+colorRes.green+colorRes.blue)*/
      return Number('0x'+colorRes.red+colorRes.green+colorRes.blue)
    }

    private function parseSRT(dat:String):Array {
      var arr:Array = new Array();
      var lst:Array = dat.split("\r\n\r\n");
      if(lst.length == 1) { lst = dat.split("\n\n"); }
      for(var i:Number=0; i<lst.length; i++) {
          var obj:Object = parseSRTCaption(lst[i]);
        if(obj['end']) { arr.push(obj); }
      }
      return arr;
    };

    /** Parse a single captions entry. **/
    private function parseSRTCaption(dat:String):Object {
      var obj:Object = new Object();
      var arr:Array = dat.split("\r\n");
      if(arr.length == 1) { arr = dat.split("\n"); }
      try { 
        var idx:Number = arr[1].indexOf(' --> ');
        obj['begin'] = Number(Strings.seconds(arr[1].substr(0,idx)));
        obj['end'] = Number(Strings.seconds(arr[1].substr(idx+5)));
        obj['text'] = arr[2];
        if(arr[3]) { obj['text'] += '<br />'+arr[3]; }
      } catch (err:Error) {}
      return obj;
    };

    public function get captions():Array{
      return _captions;
    }

    public function get parsed():Boolean{
      return (_captions.length > 0);
    }

    public function parse():void{
      // loading file
      _owner.dispatchEvent(new PlayerEvent(PlayerEvent.SUB_PARSE));
      var subLoader:URLLoader = new URLLoader();
      subLoader.addEventListener(Event.COMPLETE, parseSubFile);
      subLoader.load(new URLRequest(_file));
    }

    private function debug(mes:*):void{
      _owner.config.debug(mes);
    }

    private function dump(obj:*):void{
      debug('\n\t\t'+obj);
      for (var p:String in obj)
      {
        debug('\t\t\t'+p+':'+obj[p]);
      }
      debug('\n');
    }
  }
}