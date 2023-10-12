module sui_place::canvas{
    use std::vector;
    use sui::object::{Self, UID};
    use sui::object_bag::{Self, ObjectBag};
    use sui::bag::{Self, Bag};
    use sui::vec_map::{Self, VecMap};
    use sui::tx_context::{Self, TxContext};
    use sui::transfer;
    use sui::clock::{Self, Clock};
    use sui::event::emit;

    friend sui_place::core;

    const ERROR_WRONG_COLOR: u64 = 0;
    const ERROR_NOT_FOUND: u64 = 1;
    const ERROR_NOT_LIVE: u64 = 2;
    const ERROR_DRAW_COST: u64 = 3;
    const ERROR_OUT_OF_BOUND: u64 = 4;


    struct Color has drop, copy, store{
        r: u64,
        g: u64,
        b:u64
    }

    struct Pixel has drop, copy, store {
        owner: address,
        x: u64,
        y: u64,
        color: Color
    }

    struct Canvas has key, store {
        id: UID,
        start: u64,
        end: u64,
        height: u64,
        width: u64,
        pixels: VecMap<u64, Pixel>,
        num_of_pixel: Bag
    }

    struct CanvasStorage has key {
        id: UID,
        canvas_count: u64,
        canvas: ObjectBag
    }

    //Events
    struct Drawed has copy, drop{
        user: address,
        canvas: address,
        x:u64,
        y: u64,
        color: Color
    }

    fun init(ctx: &mut TxContext){
        let storage = CanvasStorage{
            id: object::new(ctx),
            canvas_count: 0u64,
            canvas: object_bag::new(ctx)
        };
        transfer::share_object(storage);
    }

    public entry fun initialize_canvas(
        storage: &mut CanvasStorage,
        start: u64,
        end: u64,
        height: u64,
        width: u64,
        ctx: &mut TxContext,
    ){
        let canvas = Canvas{
            id: object::new(ctx),
            start: start,
            end: end,
            height: height,
            width: width,
            pixels: vec_map::empty<u64, Pixel>(),
            num_of_pixel: bag::new(ctx)
        };
        object_bag::add(
            &mut storage.canvas,
            storage.canvas_count,
            canvas
        );
        storage.canvas_count = storage.canvas_count + 1;
    }

    public(friend) fun draw(
        storage: &mut CanvasStorage,
        canvas_id: u64,
        x: u64,
        y: u64,
        r: u64,
        g: u64,
        b: u64,
        clock: &Clock,
        ctx: &mut TxContext
    ){
        let current_timestamp = clock::timestamp_ms(clock);
        //index = y*h + x
        assert!(r < 256 && g < 256 && b < 256, 0);
        let canvas = object_bag::borrow_mut<u64, Canvas>(&mut storage.canvas, canvas_id);
        assert!(current_timestamp >= canvas.start && current_timestamp <= canvas.end, ERROR_NOT_LIVE);
        assert!(x < canvas.width - 1 && y < canvas.height - 1, ERROR_OUT_OF_BOUND);
        let pixel_index = x + y*canvas.height;
        if (vec_map::contains(&canvas.pixels, &pixel_index)){
            let (_, old_pixel) = vec_map::remove<u64, Pixel>(&mut canvas.pixels, &pixel_index);
            let old_num_pixel = bag::borrow_mut<address, u64>(&mut canvas.num_of_pixel, old_pixel.owner);
            *old_num_pixel = *old_num_pixel - 1;
        };
        if (!bag::contains<address>(&canvas.num_of_pixel, tx_context::sender(ctx))){
            bag::add<address, u64>(&mut canvas.num_of_pixel,tx_context::sender(ctx), 0);
        };
        vec_map::insert<u64, Pixel>(
            &mut canvas.pixels,
            pixel_index,
            Pixel{
                owner: tx_context::sender(ctx),
                x: x,
                y:y,
                color: Color{
                    r: r,
                    g: g,
                    b: b
                }
            }
        );
        emit(Drawed{
            user: tx_context::sender(ctx),
            canvas: object::uid_to_address(&canvas.id),
            x: x,
            y: y,
            color: Color{
                    r: r,
                    g: g,  
                    b: b
                }
        })
    }

    public(friend) fun transfer_canvas(
        storage: &mut CanvasStorage,
        canvas_id: u64,
        new_owner: address
    ){
        let canvas = object_bag::remove<u64, Canvas>(&mut storage.canvas, canvas_id);
        transfer::transfer(canvas, new_owner);
    }

    public fun pagination_pixel_by_canvas_id(
        storage: &CanvasStorage,
        canvas_id: u64,
        page: u64,
        size: u64
    ): (vector<Pixel>, u64){
        let canvas = object_bag::borrow<u64, Canvas>(&storage.canvas, canvas_id);
        pagination_pixel_by_canvas_obj(canvas, page, size)
    }

    public fun pagination_pixel_by_canvas_obj(
        canvas: &Canvas,
        page: u64,
        size: u64
    ): (vector<Pixel>, u64){
        let vec_result = vector::empty<Pixel>();
        assert!(vec_map::size(&canvas.pixels) > page * size, ERROR_OUT_OF_BOUND);
        let i = page*size;
        let end_index = if ((page + 1)*size < vec_map::size(&canvas.pixels)) {
            (page + 1)*size
        } else {
            vec_map::size(&canvas.pixels)
        };
        while (i < end_index) {
            let (_, pixel) = vec_map::get_entry_by_idx<u64, Pixel>(&canvas.pixels, i);
            vector::push_back<Pixel>(&mut vec_result, Pixel{
                owner: pixel.owner,
                x: pixel.x,
                y:pixel.y,
                color: pixel.color
            });
            i = i + 1;
        };
        (vec_result, vec_map::size(&canvas.pixels))
    }

}