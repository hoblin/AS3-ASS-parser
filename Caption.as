package classes{ 

  import flash.text.*;
  import flash.filters.DropShadowFilter;
  import caurina.transitions.Tweener;
  import caurina.transitions.properties.*;

  public class Caption extends Object{

    private var _owner:DSPlayer;
    private var _field:TextField;

    public var active:Boolean = false;
    public var begin:Number;
    public var end:Number;

    private var text:String = '';
    private var font:String = 'Arial';
    private var size:Number = 0.0556;
    private var color:Number = 0xFFFFFF;
    private var bold:Boolean = false;
    private var italic:Boolean = false;
    private var underline:Boolean = false;
    private var align:String = 'center';
    private var valign:String = 'sub';
    private var x:Number = 0;
    private var y:Number = 0;
    private var marginL:Number = 0.0;
    private var marginR:Number = 0.0;
    private var marginV:Number = 0.0;
    private var animation:Object = new Object();
    private var fadeIn:Number = 0.0;
    private var fadeOut:Number = 0.0;
    private var outline:Number = 1;
    private var outlineColor:Number = 0x000000;
    private var shadow:Number = 0;
    private var shadowColor:Number = 0x000000;
    private var frx:Number = 0;
    private var fry:Number = 0;
    private var frz:Number = 0;

    public function Caption(p_owner:DSPlayer, p_caption:Object){
      _owner = p_owner;
      var caption = this;
      for (var p:String in p_caption){
        if(caption[p] != undefined){
          caption[p] = p_caption[p];
        }
      }
    }

    public function sub(){
      _field = new TextField();
      var captionTextFormat = new TextFormat();

      captionTextFormat.rightMargin = width(marginR);
      captionTextFormat.leftMargin = width(marginL);
      captionTextFormat.font = font;
      captionTextFormat.size = countHeight(size);
      captionTextFormat.color = color;
      captionTextFormat.bold = bold;
      captionTextFormat.italic = italic;
      captionTextFormat.underline = underline;
      captionTextFormat.align = align;

      var shadowFilter = new DropShadowFilter(
          shadow*1.5, 
          45, 
          shadowColor, 
          shadow/4, 
          shadow*1.5, 
          shadow*1.5,
          shadow);
      var outlineFilter = new DropShadowFilter(
          0, 
          0, 
          outlineColor, 
          1.0, 
          outline*1.5, 
          outline*1.5,
          outline);
      _field.filters = new Array(outlineFilter, shadowFilter);

      _field.width = _owner.width;
      _field.defaultTextFormat = captionTextFormat;
      _field.multiline = true;
      _field.wordWrap = true;
      /*_field.border = true;*/
      _field.selectable = false;
      _field.autoSize = TextFieldAutoSize.CENTER;
      _field.htmlText = text;
      if((y == 0)&&(x == 0)){
        // collizions
        var activeSubsArray = _owner.getActiveSubs(valign);
        var collision_delta = 0;
        if(activeSubsArray.length > 0){
          for each (var item:Object in activeSubsArray)
          {
            collision_delta += item.height + item.marginV;
          }
        }
        if(valign == 'top'){
          _field.y = countHeight(0.0) + collision_delta;
        }else if(valign == 'mid'){
          _field.y = countHeight(0.5) + _field.height - collision_delta;
        }else{
          _field.y = countHeight(1.0) - _field.height - countHeight(marginV) - collision_delta;
        }
        _field.x = 0;
      }else{
        _field.y = countHeight(y) - _field.height + _owner.y;
        _field.x = width(x) - (_field.width / 2);
      }

      if(animation.x != undefined) animation.x = width(animation.x) - (_field.width / 2);
      if(animation.y != undefined) animation.y = countHeight(animation.y) - _field.height + _owner.y;

      if(_field.y < 0) _field.y = _owner.y;
      if(animation.y < 0) animation.y = _owner.y;

      // ROTATION
      if(frx != 0) _field.rotationX = frx;
      if(fry != 0) _field.rotationY = fry;
      if(frz != 0) _field.rotationZ = -frz;

      _field.alpha = 0;
      Tweener.addTween(_field, animation);
      Tweener.addTween(_field, {alpha:1, time:fadeIn});
      _owner.skin.subtitles_mc.addChild(_field);
      active = true;
    }

    public function unsub():void{
      Tweener.addTween(_field, {onComplete:drop, alpha:0, time:fadeOut});
    }

    private function drop():void{
      _owner.skin.subtitles_mc.removeChild(_field);
      active = false;
      _field = null;
    }

    private function width(delta:*):Number{
      return _owner.width * Number(delta);
    }

    private function countHeight(delta:*):Number{
      /*debug('H \t delta:'+delta+'\t _owner.height:'+_owner.height);*/
      return _owner.height * Number(delta);
    }

    public function get height():Number{
      return _field.height;
    }

    public function get v_align():String{
      return valign;
    }

    private function debug(mes:*):void{
      _owner.config.debug(mes);
    }
  }
}