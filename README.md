## Setup

Example document setup at ./test/hero.mo

```motoko

import Hero "./hero";


stable let hero_store = Hero.init();
let hero = Hero.use(hero_store);
```

## Usage

### Insert or Update (if using PK)

```motoko

 hero.db.insert({
        id=123;
        updatedAt= 1;
        score= 3;
        name= "B";
        level= 1;
        skills= ["Fireball","Blizzard","Thunder"];
        deleted= true
    });
```

### Delete by Idx

```motoko

 hero.db.delete(123);

```

### Index findIdx

```motoko

hero.score.findIdx(0, ^0, #fwd, 10);
// [(idxkey, 1),(idxkey, 2),(idxkey, 3)]

```

### Index find

```motoko

hero.score.find(0, ^0, #fwd, 10);
// [{id=123; name="B" ...}, ...]

```

### PK get

```motoko

hero.pk.get(123);
// {id=123; name="B" ...}

```

### PK getIdx

```motoko

hero.pk.getIdx(123);
// 1

```
